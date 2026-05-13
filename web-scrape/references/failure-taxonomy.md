# Failure Taxonomy

## `failure_type` values

### `empty_html`
**Meaning:** Page returned almost no readable content (< 200 chars).  
**Likely cause:** Empty response, blocked body, or content not present in initial HTML.  
**Next step:** Try `playwright` or `mobile-fetch`.

### `js_shell_only`
**Meaning:** Page contains JS framework / SDK markers but no real readable content.  
**Detection:** Shell markers, bot-detection SDKs, app bootstrap scripts, or “please enable JavaScript” text.  
**Next step:** Try `playwright`.

### `challenge_page`
**Meaning:** Anti-bot / challenge / CAPTCHA wall.  
**Detection:** Phrases like `challenge`, `captcha`, `安全验证`, `访问验证`, `One last step`, `Please solve the challenge below`.  
**Next step:** Try `mobile-fetch` once, then report blocked if still unavailable.

### `partial_static_content`
**Meaning:** Some public/static content is present, but important dynamic sections are missing.  
**Likely cause:** Data loaded after render or via a separate API call.  
**Next step:** Try `playwright`, inspect discovered API endpoints, or use a hostname-specific strategy if one exists.

### `http_error`
**Meaning:** HTTP status >= 400.  
**Next step:** Check URL; may be 403 (forbidden), 404 (not found), or 5xx (server error).

### `request_error`
**Meaning:** Fetch failed before a usable response was available.  
**Examples:** DNS failure, timeout, invalid URL, blocked private/local host, unsupported scheme.  
**Next step:** Report the concrete error; retry with another strategy only when that could change the outcome.

### WeChat MP reader statuses
These values can appear as `failure_type` when `strategy_used` is `wechat-mp`:

| Status | Meaning | Next step |
|--------|---------|-----------|
| `dependency_missing` | `scrapling` or browser runtime is unavailable | Report dependency gap; use a Python environment with the required dependencies installed |
| `captcha_blocked` | WeChat verification/CAPTCHA page reached | Report blocked; do not fabricate content |
| `article_page_but_selector_failed` | Page loaded but article selectors were absent | Report extraction failure |
| `article_page_but_empty_content` | Article container was present but no text extracted | Report extraction failure |
| `unsupported_url` | URL is not a supported `mp.weixin.qq.com/s/...` article | Use another strategy or route discovery through `web-research` |
| `internal_error` | Reader raised an unexpected error | Report `error_detail` |

`mixed_layout_noise` and `image_heavy` are considered usable when content was extracted; check `wechat_mp.warnings`, `content_mode`, and images.

---

## Common failure signatures

| Signature | Site type | Root cause |
|-----------|-----------|------------|
| `ncDisable` | Alibaba-style risk control | Request blocked or JS challenge required |
| `WindVane` / `MTOPSDK` | App/web hybrid SDK | Browser-like runtime expected |
| `aplus_v2.js` | Analytics / shell-heavy page | Basic fetch may only see bootstrap content |
| `spider/bot` | Generic anti-bot | Direct request rejected |
| `AliApp/WindVane` | Alibaba-style SDK | UA / runtime detection |
| `captcha` | Generic | Human verification triggered |
| `请打开 Javascript` | Generic | JS required but not rendered |

---

## Strategy selection quick-ref

```text
1. Try html-fetch for normal pages.
2. If content is empty or shell-only, try playwright.
3. If blocked by a challenge, try mobile-fetch once.
4. If dynamic sections are missing, use playwright and inspect API endpoints.
5. If the hostname is listed in site-strategies.json, use site-strategy.
```

## Notes

- Never hallucinate content when fetch fails. Report failure type clearly.
- Placeholder-only fields or missing dynamic sections should be classified as `partial_static_content`.
- If Playwright also fails with a challenge, try mobile UA once before giving up.
