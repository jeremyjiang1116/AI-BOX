# Advanced Search Reference

Keep this file compact. Use `scripts/build-search-url.mjs` to generate engine URLs instead of hand-writing long `web_fetch` examples.

## Operators

| Operator | Example | Notes |
|---|---|---|
| `site:` | `site:github.com openclaw` | Search inside one domain. |
| `filetype:` | `filetype:pdf report` | Find PDFs, docs, spreadsheets, etc. |
| `"..."` | `"exact phrase"` | Require exact phrase match. |
| `-term` | `python -snake` | Exclude a term. |
| `OR` | `react OR vue` | Either term may match. |
| `intitle:` | `intitle:tutorial python` | Title contains term. |
| `inurl:` | `inurl:docs api` | URL contains term. |

## Time filters

Google-compatible engines often accept:

| Filter | Meaning |
|---|---|
| `tbs=qdr:h` | past hour |
| `tbs=qdr:d` | past day |
| `tbs=qdr:w` | past week |
| `tbs=qdr:m` | past month |
| `tbs=qdr:y` | past year |

## Chinese / WeChat search

- Use `--mode wechat` for public-account article discovery.
- Use `--mode cn` for broader Chinese web coverage.
- Prefer WeChat and Sogou for 公众号 articles; add Baidu/Bing CN when coverage is weak.

## Global cross-checking

Use `--mode verify` for independent cross-check URLs:

```bash
node scripts/build-search-url.mjs --query "claim to verify" --mode verify --json
```

Then fetch a small number of high-value result pages and pass known URLs to `web-scrape` when full text is needed.
