#!/usr/bin/env python3
"""
fetch-url.py - Multi-strategy HTTP(S) URL fetcher.

Run with a Python environment that has optional Playwright support when needed.
"""

from __future__ import annotations

import argparse
from concurrent.futures import ThreadPoolExecutor, TimeoutError
from dataclasses import asdict
import ipaddress
import json
import os
import re
import socket
import sys
import urllib.error
import urllib.request
from html import unescape
from urllib.parse import urlparse

PLAYWRIGHT_AVAILABLE = False
try:
    from playwright.sync_api import sync_playwright

    PLAYWRIGHT_AVAILABLE = True
except ImportError:
    pass

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
BASE_DIR = os.path.dirname(SCRIPT_DIR)
SITE_STRATEGIES_PATH = os.path.join(BASE_DIR, "references", "site-strategies.json")

MAX_RESPONSE_BYTES = 5_000_000
DNS_RESOLUTION_TIMEOUT_SECONDS = 5
MOBILE_UA = "Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Mobile/15E148 Safari/604.1"
DESKTOP_UA = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"
WECHAT_HOST = "mp.weixin.qq.com"


def is_wechat_mp_article_url(url: str) -> bool:
    parsed = urlparse(url.strip())
    return parsed.scheme in {"http", "https"} and (parsed.hostname or "").lower() == WECHAT_HOST and parsed.path.startswith("/s")


def parse_args(argv: list[str]) -> dict:
    parser = argparse.ArgumentParser(description="Multi-strategy HTTP(S) URL fetcher")
    parser.add_argument("--url", required=True, help="HTTP(S) URL to fetch")
    parser.add_argument(
        "--strategy",
        default="html-fetch",
        choices=["html-fetch", "playwright", "mobile-fetch", "site-strategy", "wechat-mp"],
    )
    parser.add_argument("--timeout", type=int, default=25000, help="Timeout in milliseconds")
    parser.add_argument("--json", action="store_true", help="Emit JSON output")
    parser.add_argument(
        "--allow-private-hosts",
        action="store_true",
        help="Allow localhost/private/link-local hosts. Use only for explicitly authorized internal targets.",
    )
    return vars(parser.parse_args(argv))


def _is_private_ip(ip: str) -> bool:
    addr = ipaddress.ip_address(ip)
    return any(
        [
            addr.is_private,
            addr.is_loopback,
            addr.is_link_local,
            addr.is_reserved,
            addr.is_multicast,
            addr.is_unspecified,
        ]
    )


def resolve_host(host: str, timeout_seconds: int = DNS_RESOLUTION_TIMEOUT_SECONDS):
    executor = ThreadPoolExecutor(max_workers=1)
    try:
        future = executor.submit(socket.getaddrinfo, host, None, proto=socket.IPPROTO_TCP)
        return future.result(timeout=timeout_seconds)
    except TimeoutError as e:
        raise ValueError(f"DNS resolution timed out after {timeout_seconds}s") from e
    finally:
        executor.shutdown(wait=False, cancel_futures=True)


def validate_url(url: str, allow_private_hosts: bool = False) -> None:
    parsed = urlparse(url)
    if parsed.scheme not in {"http", "https"} or not parsed.hostname:
        raise ValueError("only http(s) URLs with a hostname are supported")

    if allow_private_hosts:
        return

    host = parsed.hostname.lower().rstrip(".")
    if host in {"localhost", "localhost.localdomain"} or host.endswith(".local"):
        raise ValueError("private/local hosts are blocked unless --allow-private-hosts is set")

    try:
        if _is_private_ip(host):
            raise ValueError("private/local hosts are blocked unless --allow-private-hosts is set")
        return
    except ValueError as e:
        if "blocked" in str(e):
            raise
        # Not an IP literal; resolve below.

    try:
        infos = resolve_host(host)
    except socket.gaierror:
        return

    for info in infos:
        ip = info[4][0]
        if _is_private_ip(ip):
            raise ValueError("private/local hosts are blocked unless --allow-private-hosts is set")


def read_limited_response(resp) -> tuple[str, bool]:
    data = resp.read(MAX_RESPONSE_BYTES + 1)
    truncated = len(data) > MAX_RESPONSE_BYTES
    if truncated:
        data = data[:MAX_RESPONSE_BYTES]
    return data.decode("utf-8", errors="replace"), truncated


def strip_html(html: str) -> str:
    if not html:
        return ""
    text = re.sub(r"<script[^>]*>[\s\S]*?</script>", "", html, flags=re.I)
    text = re.sub(r"<style[^>]*>[\s\S]*?</style>", "", text, flags=re.I)
    text = re.sub(r"<[^>]+>", " ", text)
    text = unescape(text)
    text = re.sub(r"\s+", " ", text).strip()
    return text


def extract_title_from_html(raw: str) -> str:
    m = re.search(r"<title[^>]*>([^<]+)</title>", raw or "", re.I)
    if m:
        return unescape(m.group(1)).strip()
    return ""


def classify_failure(text: str, url: str, status: int | None = None, error: str | None = None) -> str | None:
    raw = text or ""
    lowered = raw.lower()

    if any(kw in lowered for kw in ["challenge", "captcha", "安全验证", "访问验证", "one last step", "solve the challenge"]):
        return "challenge_page"
    if status and status >= 400:
        return "http_error"
    if error:
        return "request_error"

    visible_text = strip_html(raw)
    shell_markers = ["<script", "id=\"app\"", "id='app'", "__next", "webpack", "vite"]
    if not visible_text:
        if any(kw in lowered for kw in shell_markers):
            return "js_shell_only"
        return "empty_html"
    if len(visible_text) < 200:
        if any(kw in lowered for kw in shell_markers):
            return "js_shell_only"
        if not re.search(r"<(title|h1|h2|p|article|main)\b", raw, re.I):
            return "empty_html"

    if any(kw in lowered for kw in ["maitix", "ncdisable", "windvane", "mtopsdk", "spider/bot", "aplus_v2.js", "aliapp"]):
        return "js_shell_only"
    if "请打开 javascript" in lowered or ("javascript" in lowered and "noscript" in lowered):
        return "js_shell_only"
    if re.search(r"(loading|加载中|暂无数据|--|待定)", visible_text, re.I) and len(visible_text) < 2000:
        return "partial_static_content"
    return None


def html_fetch(url: str, timeout_ms: int = 15000) -> dict:
    req = urllib.request.Request(
        url,
        headers={
            "User-Agent": DESKTOP_UA,
            "Accept": "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8",
            "Accept-Language": "zh-CN,zh;q=0.9,en;q=0.8",
        },
    )
    try:
        resp = urllib.request.urlopen(req, timeout=timeout_ms / 1000)
        raw, truncated = read_limited_response(resp)
        return {"raw": raw, "status": resp.status, "truncated": truncated}
    except urllib.error.HTTPError as e:
        raw = ""
        try:
            raw, _ = read_limited_response(e)
        except Exception:
            pass
        return {"raw": raw, "status": e.code, "error": str(e)}
    except Exception as e:
        return {"raw": "", "status": 0, "error": str(e)}


def mobile_fetch(url: str, timeout_ms: int = 15000) -> dict:
    req = urllib.request.Request(
        url,
        headers={
            "User-Agent": MOBILE_UA,
            "Accept": "text/html,application/xhtml+xml,*/*",
            "Accept-Language": "zh-CN,zh;q=0.9",
        },
    )
    try:
        resp = urllib.request.urlopen(req, timeout=timeout_ms / 1000)
        raw, truncated = read_limited_response(resp)
        return {"raw": raw, "status": resp.status, "truncated": truncated}
    except urllib.error.HTTPError as e:
        raw = ""
        try:
            raw, _ = read_limited_response(e)
        except Exception:
            pass
        return {"raw": raw, "status": e.code, "error": str(e)}
    except Exception as e:
        return {"raw": "", "status": 0, "error": str(e)}


def playwright_fetch(url: str, timeout_ms: int = 25000) -> dict:
    if not PLAYWRIGHT_AVAILABLE:
        return {"error": "playwright not available in Python venv", "textContent": ""}

    with sync_playwright() as p:
        browser = p.chromium.launch(
            headless=True,
            args=["--no-sandbox", "--disable-setuid-sandbox", "--disable-dev-shm-usage"],
        )
        try:
            context = browser.new_context(
                user_agent=DESKTOP_UA,
                viewport={"width": 1280, "height": 800},
                locale="zh-CN",
            )
            page = context.new_page()
            console_errors: list[str] = []
            requested_urls: set[str] = set()

            page.on("console", lambda msg: console_errors.append(msg.text) if msg.type == "error" else None)
            page.on("request", lambda req: requested_urls.add(req.url))

            page.goto(url, wait_until="load", timeout=timeout_ms)
            page.wait_for_timeout(3000)
            text_content = page.evaluate("() => document.body ? document.body.innerText : ''")
            if len(text_content) < 200:
                page.wait_for_timeout(5000)
                text_content = page.evaluate("() => document.body ? document.body.innerText : ''")

            scripts = page.evaluate(r"""() => {
                const out = [];
                try {
                    document.querySelectorAll('script').forEach(s => {
                        if (s.src) out.push({type:'src', value:s.src});
                        const text = s.innerText || '';
                        const urls = text.match(/https?:\/\/[a-zA-Z0-9_.\-\/?&=%:#]+/g) || [];
                        urls.forEach(u => out.push({type:'inline_url', value:u}));
                    });
                } catch(e) {}
                return out;
            }""")
            scripts.extend({"type": "request", "value": u} for u in requested_urls)
            return {"textContent": text_content, "title": page.title(), "scripts": scripts, "errors": console_errors}
        except Exception as e:
            return {"error": str(e), "textContent": ""}
        finally:
            browser.close()


def site_strategy(url: str) -> tuple[str, dict] | None:
    if not os.path.exists(SITE_STRATEGIES_PATH):
        return None
    try:
        with open(SITE_STRATEGIES_PATH, encoding="utf-8") as f:
            strategies = json.load(f)
    except Exception:
        return None

    host = (urlparse(url).hostname or "").lower().rstrip(".")
    for hostname, cfg in sorted(strategies.items(), key=lambda item: len(item[0]), reverse=True):
        normalized = hostname.lower().rstrip(".")
        if "." not in normalized:
            continue
        if host == normalized or host.endswith(f".{normalized}"):
            return normalized, cfg
    return None


def extract_api_endpoints(scripts) -> list[str]:
    endpoints = set()

    def clean_endpoint(value: str) -> str:
        return value.rstrip("'\"`),.;]")

    def is_api_like(value: str) -> bool:
        return any(
            re.search(pattern, value, re.I)
            for pattern in [
                r"/(api|openapi|v\d+|rest|graphql|ajax|json)(/|\?|$)",
                r"//api\.",
                r"(^|/)graphql($|/|\?)",
            ]
        )

    absolute_pattern = r"https?://[^\s'\"<>`)]+"
    protocol_relative_pattern = r"//api\.[^\s'\"<>`)]+"
    relative_pattern = r"(?<![A-Za-z0-9_])/(?:api|openapi|v\d+|rest|graphql|ajax|json)(?:/[^\s'\"<>`)]*)?(?:\?[^\s'\"<>`)]*)?"

    for item in scripts or []:
        text = item.get("value", "") if isinstance(item, dict) else str(item)
        for pattern in [absolute_pattern, protocol_relative_pattern, relative_pattern]:
            for match in re.findall(pattern, text):
                endpoint = clean_endpoint(match)
                if endpoint and is_api_like(endpoint):
                    endpoints.add(endpoint)
    return sorted(endpoints)


def build_output(url: str, requested_strategy: str, result: dict, failure_type: str | None) -> dict:
    if result.get("wechat_result"):
        payload = dict(result["wechat_result"])
        content = payload.get("content") or ""
        text_content = content[:8000]
        status = payload.get("status") or "internal_error"
        resolved_strategy = result.get("resolved_strategy") or "wechat-mp"
        usable = status in {"ok", "mixed_layout_noise", "image_heavy"} and bool(content)
        notes = "OK" if status == "ok" else f"WeChat reader status: {status}"
        if payload.get("error_detail"):
            notes = payload["error_detail"]
        return {
            "url": url,
            "requested_strategy": requested_strategy,
            "resolved_strategy": resolved_strategy,
            "strategy_used": resolved_strategy,
            "site_strategy_matched": result.get("site_strategy_matched"),
            "failure_type": failure_type,
            "title": payload.get("title", ""),
            "text_content": text_content,
            "api_endpoints": [],
            "raw_length": len(content),
            "usable": usable,
            "notes": notes,
            "wechat_mp": payload,
        }

    raw = result.get("raw") or result.get("textContent") or ""
    title = result.get("title") or (extract_title_from_html(raw) if result.get("raw") else "")
    text_content = strip_html(raw) if raw else ""
    if len(text_content) > 8000:
        text_content = text_content[:8000]

    scripts = list(result.get("scripts") or [])
    if result.get("raw"):
        scripts.append({"type": "raw_html", "value": result.get("raw", "")})

    resolved_strategy = result.get("resolved_strategy") or requested_strategy

    return {
        "url": url,
        "requested_strategy": requested_strategy,
        "resolved_strategy": resolved_strategy,
        "strategy_used": resolved_strategy,
        "site_strategy_matched": result.get("site_strategy_matched"),
        "failure_type": failure_type,
        "title": title,
        "text_content": text_content,
        "api_endpoints": extract_api_endpoints(scripts),
        "raw_length": len(raw),
        "usable": not failure_type and not result.get("error") and bool(text_content),
        "notes": result.get("error", "") or (f"Failure: {failure_type}" if failure_type else "OK"),
    }


def run_strategy(url: str, strategy: str, timeout_ms: int) -> dict:
    if is_wechat_mp_article_url(url) and strategy != "wechat-mp":
        strategy = "wechat-mp"
    if strategy == "wechat-mp":
        try:
            from wechat_mp_read import read_article

            result = asdict(read_article(url, backoff_seconds=0))
            return {"wechat_result": result, "resolved_strategy": "wechat-mp", "site_strategy_matched": WECHAT_HOST}
        except Exception as e:
            return {"error": str(e), "raw": "", "resolved_strategy": "wechat-mp", "site_strategy_matched": WECHAT_HOST}
    if strategy == "html-fetch":
        result = html_fetch(url, timeout_ms)
        result.update({"resolved_strategy": "html-fetch", "site_strategy_matched": None})
        return result
    if strategy == "mobile-fetch":
        result = mobile_fetch(url, timeout_ms)
        result.update({"resolved_strategy": "mobile-fetch", "site_strategy_matched": None})
        return result
    if strategy == "playwright":
        result = playwright_fetch(url, timeout_ms)
        result.update({"resolved_strategy": "playwright", "site_strategy_matched": None})
        return result
    if strategy == "site-strategy":
        matched = site_strategy(url)
        if not matched:
            return {"error": "no site strategy found", "raw": "", "resolved_strategy": "site-strategy", "site_strategy_matched": None}
        matched_hostname, cfg = matched
        resolved_strategy = cfg.get("strategy", "playwright")
        result = run_strategy(url, resolved_strategy, timeout_ms)
        result.update({"resolved_strategy": resolved_strategy, "site_strategy_matched": matched_hostname})
        return result
    return {"error": f"unknown strategy: {strategy}", "raw": "", "resolved_strategy": strategy, "site_strategy_matched": None}


def main() -> None:
    args = parse_args(sys.argv[1:])
    try:
        validate_url(args["url"], allow_private_hosts=args["allow_private_hosts"])
        result = run_strategy(args["url"], args["strategy"], args["timeout"])
        if result.get("wechat_result"):
            wechat_status = result["wechat_result"].get("status")
            failure_type = None if wechat_status in {"ok", "mixed_layout_noise", "image_heavy"} else wechat_status
        else:
            failure_type = classify_failure(
                result.get("raw") or result.get("textContent") or "",
                args["url"],
                result.get("status"),
                result.get("error"),
            )
    except ValueError as e:
        result = {"error": str(e), "raw": ""}
        failure_type = "request_error"

    out = build_output(args["url"], args["strategy"], result, failure_type)

    if args["json"]:
        print(json.dumps(out, ensure_ascii=False, indent=2))
    else:
        print(f"[{out['resolved_strategy']}] {out['title'] or 'no title'}")
        if out["requested_strategy"] != out["resolved_strategy"]:
            print(f"requested_strategy={out['requested_strategy']} site_strategy_matched={out['site_strategy_matched'] or 'none'}")
        print(f"usable={out['usable']} failure_type={out['failure_type'] or 'none'}")
        print(f"chars={out['raw_length']}")
        if out["api_endpoints"]:
            print(f"apis={', '.join(out['api_endpoints'][:5])}")
        print(f"notes={out['notes']}")
        print("---")
        print(out["text_content"][:2000])


if __name__ == "__main__":
    main()
