---
name: web-scrape
description: "Fetch and extract readable content from known URLs, including WeChat official account article URLs (`mp.weixin.qq.com/s/...`). Use when a user asks to fetch, extract, parse, or summarize a URL; when a search result needs full-page extraction; when normal web_fetch is empty/blocked/JS-only; or when structured page data must be extracted. Supports WeChat MP article extraction, plain HTML fetch, Playwright rendering, mobile-UA fallback, API endpoint discovery, and optional hostname-specific strategy overrides."
---

# Web Scrape

Multi-strategy HTTP(S) URL fetcher for known URLs, including static pages, JS-rendered pages, simple anti-bot blocks, partial dynamic pages, and WeChat official account articles.

Use the bundled Python fetcher with a Python environment that has the needed optional dependencies installed. For OpenClaw installs, this is commonly `$HOME/.openclaw/.venv-web/bin/python3`.

## Execution Protocol

### Step 1: Quick classification

Use the most general viable strategy first. Only use a hostname-specific override when the URL hostname matches `references/site-strategies.json`.

| Pattern | Default strategy |
|---------|------------------|
| WeChat official account article (`mp.weixin.qq.com/s/...`) | `wechat-mp` |
| Static news/blog/article/docs | `html-fetch` |
| GitHub raw file / API / plain text | `html-fetch` |
| JS-heavy SPA (React/Vue/app shell) | `playwright` |
| Dynamic catalog/product/event/listing page | `html-fetch` first, then `playwright` if data is missing |
| Login/Auth wall | `html-fetch` for partial public content; report limitation |
| Anti-bot/challenge page | `mobile-fetch` once; report if still blocked |
| Hostname exists in site strategy DB | `site-strategy` |
| Unknown | `html-fetch` first, escalate on failure |

### Step 2: Try primary strategy

Resolve these relative paths against this skill directory.

```bash
# WeChat official account article reader (auto-selected for mp.weixin.qq.com/s/...)
python3 scripts/fetch-url.py --url "<url>" --strategy wechat-mp --json

# HTML fetch (fast, static pages)
python3 scripts/fetch-url.py --url "<url>" --strategy html-fetch --json

# Playwright JS rendering (for SPA/dynamic pages)
python3 scripts/fetch-url.py --url "<url>" --strategy playwright --timeout 40000 --json

# Mobile UA fallback
python3 scripts/fetch-url.py --url "<url>" --strategy mobile-fetch --json

# Hostname-specific strategy from references/site-strategies.json
python3 scripts/fetch-url.py --url "<url>" --strategy site-strategy --json
```

### Step 3: Evaluate result — classify failure type

| Failure tag | Meaning | Next action |
|-------------|---------|-------------|
| `empty_html` | Page returned almost no readable content | Try `playwright` or `mobile-fetch` |
| `js_shell_only` | Only JS/app shell detected, no real content | Try `playwright` |
| `challenge_page` | Challenge / anti-bot wall detected | Try `mobile-fetch` once or report blocked |
| `partial_static_content` | Some content exists but dynamic sections are missing | Try `playwright` or inspect API endpoints |
| `http_error` | HTTP status >= 400 | Check URL and report status |
| `request_error` | Fetch failed before usable response | Report error or retry with another strategy if appropriate |
| `dependency_missing` | WeChat reader dependency/browser runtime is missing | Report dependency gap; use a Python environment with the required dependencies installed |
| `captcha_blocked` | WeChat CAPTCHA/verification page reached | Report blocked; do not fabricate article content |
| `article_page_but_selector_failed` | WeChat page loaded but article selectors were absent | Report extraction failure |
| `article_page_but_empty_content` | WeChat article container was present but empty | Report extraction failure |

### Step 4: Escalate carefully

```bash
# Escalate from html-fetch to playwright
python3 scripts/fetch-url.py --url "<url>" --strategy playwright --json

# Use hostname-specific override only when the hostname is present in the strategy DB
python3 scripts/fetch-url.py --url "<url>" --strategy site-strategy --json
```

## WeChat MP Articles

For `mp.weixin.qq.com/s/...` article URLs, always use `wechat-mp`; `fetch-url.py` auto-routes matching URLs to this strategy even if another strategy is requested. Discovery remains outside this skill: if the user only provides keywords or asks to find WeChat articles, use `web-research` first.

The WeChat reader returns the normal top-level JSON plus a `wechat_mp` object containing `status`, `normalized_url`, `final_url`, `account`, `publish_time`, `content`, `content_preview`, `image_urls`, `warnings`, and `error_detail`.

WeChat statuses include `ok`, `captcha_blocked`, `article_page_but_selector_failed`, `article_page_but_empty_content`, `mixed_layout_noise`, `image_heavy`, `rate_limited`, `unsupported_url`, `dependency_missing`, and `internal_error`.

## Hostname-Specific Strategies

Detailed per-site notes live in `references/site-strategies.json` and are not general trigger criteria.

Rules:
- Treat the skill trigger as generic URL extraction, not a vertical-specific crawler.
- Do not infer a domain strategy from keywords alone; match the URL hostname first.
- Hostname matching is exact or subdomain-only. Do not use arbitrary substring matching.
- If a strategy entry is stale or too narrow, prefer the general fallback sequence and note uncertainty.
- Keep new one-off site observations in `references/site-strategies.json`, not in this top-level SKILL.md.

## Safety Notes

- The fetcher only accepts `http` and `https` URLs.
- Local/private/link-local hosts are blocked by default to reduce SSRF risk. Use `--allow-private-hosts` only for explicitly authorized internal targets.
- Responses are capped before decoding to avoid loading very large pages into memory.
- Public hostnames are DNS-resolved with a bounded timeout before fetching so private-IP redirects can be blocked without hanging indefinitely.

## Anti-Bot Notes

- Search engine result pages often trigger challenges; prefer `web-research` for search tasks.
- JS-heavy Chinese sites may use Alibaba WindVane / MTOP SDK detection; try `playwright`, then `mobile-fetch` if blocked.
- If Playwright also hits a challenge, report the limitation instead of hallucinating content.

## Output Format (JSON mode)

```json
{
  "url": "<url>",
  "requested_strategy": "site-strategy",
  "resolved_strategy": "playwright",
  "strategy_used": "playwright",
  "site_strategy_matched": "example.com",
  "failure_type": null,
  "title": "<title>",
  "text_content": "<readable text>",
  "api_endpoints": ["<discovered API URL>"],
  "raw_length": 12345,
  "usable": true,
  "notes": "OK"
}
```

## When to Give Up

Report failure with a failure type; do not hallucinate. Examples:

```text
[empty_html] Basic fetch returned only a shell; recommend Playwright retry.
[challenge_page] Page is blocked by a verification challenge; mobile UA also failed.
[request_error] Request failed before content could be retrieved.
```

## References

- Site strategies: `references/site-strategies.json` (hostname → strategy mapping)
- Failure taxonomy: `references/failure-taxonomy.md`
- Fetcher script: `scripts/fetch-url.py`
- WeChat MP reader module: `scripts/wechat_mp_read.py`
