#!/usr/bin/env python3
"""Stable WeChat MP article reader for known mp.weixin.qq.com article URLs.

Discovery is explicitly out of scope. This runner only reads validated article URLs.
"""

from __future__ import annotations

import argparse
import json
import os
import re
import sys
import time
from dataclasses import asdict, dataclass, field
from html import unescape
from pathlib import Path
from typing import Any
from urllib.parse import parse_qsl, urlencode, urlparse, urlunparse

MOBILE_UA = (
    "Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) "
    "AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 "
    "Mobile/15E148 Safari/604.1"
)
SUPPORTED_HOSTS = {"mp.weixin.qq.com"}
TEXT_PREVIEW_LIMIT = 1000
IMAGE_HEAVY_TEXT_THRESHOLD = 120
DEFAULT_BACKOFF_SECONDS = 1.0

NOISE_MARKERS = [
    "参考链接：",
    "——好文推荐——",
    "封面来源｜",
    "点\n赞",
    "三连",
    "微信扫一扫赞赏作者",
    "Love the Author",
    "Like the Author",
    "Other Amount",
    "System error. Try again later.",
    "Loading...",
    "赞赏后展示我的头像",
    "最低赞赏",
    "暂无作品",
]


@dataclass
class ReadResult:
    status: str
    input_url: str
    normalized_url: str = ""
    final_url: str = ""
    title: str = ""
    account: str = ""
    publish_time: str = ""
    content: str = ""
    content_preview: str = ""
    content_length: int = 0
    content_mode: str = "text"
    image_count: int = 0
    image_urls: list[str] = field(default_factory=list)
    warnings: list[str] = field(default_factory=list)
    error_detail: str = ""

    def finalize(self) -> "ReadResult":
        self.content_preview = self.content[:TEXT_PREVIEW_LIMIT]
        self.content_length = len(self.content)
        self.image_count = len(self.image_urls)
        return self


class DependencyMissingError(RuntimeError):
    pass


def discover_python_candidates() -> list[Path]:
    candidates: list[Path] = []

    env_python = os.environ.get("WECHAT_MP_READER_PYTHON", "").strip()
    if env_python:
        candidates.append(Path(env_python).expanduser())

    current = Path(sys.executable)
    candidates.append(current)

    search_roots: list[Path] = []
    env_roots = os.environ.get("WECHAT_MP_READER_PYTHON_ROOTS", "").strip()
    if env_roots:
        for entry in env_roots.split(os.pathsep):
            if entry.strip():
                search_roots.append(Path(entry).expanduser())

    home = Path.home()
    search_roots.extend([home / ".openclaw" / "workspace", home / ".openclaw"])
    for root in search_roots:
        if not root.exists():
            continue
        try:
            for pyvenv in root.glob("**/pyvenv.cfg"):
                bin_python = pyvenv.parent / "bin" / "python"
                if bin_python.exists():
                    candidates.append(bin_python)
        except Exception:
            continue

    candidates.append(Path("/usr/bin/python3"))

    seen: set[str] = set()
    unique: list[Path] = []
    for candidate in candidates:
        key = str(candidate)
        if key in seen:
            continue
        seen.add(key)
        unique.append(candidate)
    return unique


def dependency_hint() -> str:
    checked = [str(path) for path in discover_python_candidates()[:8]]
    return "Checked Python interpreters: " + ", ".join(checked)


def import_fetcher():
    try:
        from scrapling.fetchers import DynamicFetcher  # type: ignore
    except Exception as exc:  # pragma: no cover
        raise DependencyMissingError(f"{exc}. {dependency_hint()}") from exc
    return DynamicFetcher


def normalize_wechat_url(url: str) -> str:
    parsed = urlparse(url.strip())
    query = [(k, v) for k, v in parse_qsl(parsed.query, keep_blank_values=True) if k != "scene"]
    query.append(("scene", "1"))
    normalized_query = urlencode(query)
    return urlunparse((parsed.scheme or "https", parsed.netloc, parsed.path, parsed.params, normalized_query, ""))


def is_supported_wechat_url(url: str) -> bool:
    try:
        parsed = urlparse(url.strip())
    except Exception:
        return False
    return parsed.scheme in {"http", "https"} and parsed.netloc.lower() in SUPPORTED_HOSTS and parsed.path.startswith("/s")


def clean_text(text: str) -> str:
    text = unescape(text or "")
    text = text.replace("\r", "").replace("\u200b", "")
    text = re.sub(r"[ \t]+", " ", text)
    text = re.sub(r" *\n *", "\n", text)
    text = re.sub(r"\n{3,}", "\n\n", text)
    return text.strip()


def trim_noise_tail(text: str) -> tuple[str, bool]:
    cut_points = [text.find(marker) for marker in NOISE_MARKERS if marker in text]
    if not cut_points:
        return text.strip(), False
    trimmed = text[: min(cut_points)].strip()
    return trimmed, True


def first_nonempty(*values: Any) -> str:
    for value in values:
        if value is None:
            continue
        string = str(value).strip()
        if string:
            return string
    return ""


def extract_title(page: Any, content: str) -> str:
    candidates = [
        page.css("#activity-name::text").get(),
        page.re_first(r"var msg_title = '(.*?)'"),
        page.re_first(r'var msg_title = "(.*?)"'),
        page.re_first(r"window\\.msg_title = '(.*?)'"),
        page.re_first(r'<meta property="og:title" content="(.*?)"'),
        page.re_first(r'<meta name="twitter:title" content="(.*?)"'),
        page.re_first(r"<title>(.*?)</title>"),
    ]
    for candidate in candidates:
        candidate = clean_text(first_nonempty(candidate))
        if candidate and candidate != "微信公众平台":
            return candidate

    for line in [line.strip(' "“”') for line in content.splitlines() if line.strip()][:12]:
        if len(line) < 12:
            continue
        if any(line.startswith(prefix) for prefix in ("编辑", "作者", "来源", "分享")):
            continue
        if line.endswith(("。", "！", "？")):
            continue
        return line
    return ""


def extract_image_urls(page: Any) -> list[str]:
    urls: list[str] = []
    for img in page.css("#js_content img, .rich_media_content img"):
        attrib = getattr(img, "attrib", {}) or {}
        src = first_nonempty(attrib.get("data-src"), attrib.get("src"))
        if not src:
            continue
        if src.startswith("//"):
            src = f"https:{src}"
        if src not in urls:
            urls.append(src)
    return urls


def classify_rate_limit(text: str, final_url: str) -> bool:
    lowered = text.lower()
    return "too many requests" in lowered or "rate limit" in lowered or "frequency" in lowered or "freq control" in lowered or "429" in lowered or "freqoverflow" in final_url.lower()


def read_article(url: str, backoff_seconds: float = DEFAULT_BACKOFF_SECONDS) -> ReadResult:
    if not is_supported_wechat_url(url):
        return ReadResult(status="unsupported_url", input_url=url, error_detail="Only mp.weixin.qq.com article URLs are supported.").finalize()

    normalized_url = normalize_wechat_url(url)

    try:
        DynamicFetcher = import_fetcher()
    except DependencyMissingError as exc:
        return ReadResult(status="dependency_missing", input_url=url, normalized_url=normalized_url, error_detail=str(exc)).finalize()

    if backoff_seconds > 0:
        time.sleep(backoff_seconds)

    try:
        page = DynamicFetcher.fetch(
            normalized_url,
            headless=True,
            network_idle=True,
            useragent=MOBILE_UA,
        )
        final_url = getattr(page, "url", normalized_url) or normalized_url
        html = ""
        body = getattr(page, "body", b"") or b""
        if isinstance(body, bytes):
            html = body.decode("utf-8", "ignore")
        else:
            html = str(body)

        is_captcha = "wappoc_appmsgcaptcha" in final_url or "wappoc_appmsgcaptcha" in html
        is_rate_limited = classify_rate_limit(html, final_url)
        account = first_nonempty(page.css("#js_name::text").get())
        publish_time = first_nonempty(page.css("#publish_time::text").get())
        content_node = page.css("#js_content").first or page.css(".rich_media_content").first
        raw_content = clean_text(content_node.get_all_text(strip=True)) if content_node else ""
        content, had_noise = trim_noise_tail(raw_content)
        image_urls = extract_image_urls(page)
        title = extract_title(page, content)

        result = ReadResult(
            status="ok",
            input_url=url,
            normalized_url=normalized_url,
            final_url=final_url,
            title=title,
            account=account,
            publish_time=publish_time,
            content=content,
            image_urls=image_urls[:20],
        )

        if is_captcha:
            result.status = "captcha_blocked"
        elif not content_node:
            result.status = "article_page_but_selector_failed"
        elif not content:
            result.status = "article_page_but_empty_content"
        elif image_urls and len(content) < IMAGE_HEAVY_TEXT_THRESHOLD:
            result.status = "image_heavy"
            result.content_mode = "image_heavy"
        elif had_noise:
            result.status = "mixed_layout_noise"
            result.warnings.append("noise_trimmed")
        elif is_rate_limited:
            result.status = "ok"
            result.warnings.append("rate_limit_signal_detected")

        if image_urls and result.content_mode != "image_heavy" and len(content) < IMAGE_HEAVY_TEXT_THRESHOLD:
            result.content_mode = "image_heavy"

        return result.finalize()
    except Exception as exc:
        return ReadResult(
            status="internal_error",
            input_url=url,
            normalized_url=normalized_url,
            error_detail=f"{type(exc).__name__}: {exc}",
        ).finalize()


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Read known WeChat MP article URLs and return a stable JSON schema.")
    parser.add_argument("urls", nargs="*", help="One or more mp.weixin.qq.com article URLs")
    parser.add_argument("--input-file", help="Read URLs from a text file, one per line")
    parser.add_argument("--pretty", action="store_true", help="Pretty-print JSON output")
    parser.add_argument("--backoff-seconds", type=float, default=DEFAULT_BACKOFF_SECONDS, help="Sleep before fetch to reduce request burst risk")
    return parser.parse_args()


def load_urls(args: argparse.Namespace) -> list[str]:
    urls = list(args.urls)
    if args.input_file:
        path = Path(args.input_file)
        urls.extend([line.strip() for line in path.read_text(encoding="utf-8").splitlines() if line.strip()])
    return urls


def main() -> int:
    args = parse_args()
    urls = load_urls(args)
    if not urls:
        payload: Any = {
            "status": "internal_error",
            "input_url": "",
            "normalized_url": "",
            "final_url": "",
            "title": "",
            "account": "",
            "publish_time": "",
            "content": "",
            "content_preview": "",
            "content_length": 0,
            "content_mode": "text",
            "image_count": 0,
            "image_urls": [],
            "warnings": [],
            "error_detail": "No URL provided.",
        }
        print(json.dumps(payload, ensure_ascii=False, indent=2 if args.pretty else None))
        return 1

    results = [asdict(read_article(url, backoff_seconds=args.backoff_seconds)) for url in urls]
    payload = results[0] if len(results) == 1 else results
    print(json.dumps(payload, ensure_ascii=False, indent=2 if args.pretty else None))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
