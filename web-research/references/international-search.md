# International Search Reference

Use this as a compact engine-selection guide. Generate actual URLs with:

```bash
node scripts/build-search-url.mjs --query "..." --mode global --json
node scripts/build-search-url.mjs --query "..." --mode verify --json
node scripts/build-search-url.mjs --query "..." --engine DuckDuckGo --json
```

## Engine selection

| Engine | Best use | Notes |
|---|---|---|
| DuckDuckGo | Fast general fallback, privacy-friendly result pages | Good first global fallback when Tavily is absent. |
| Bing INT | Cross-checking and broad indexed web coverage | Useful for verification mode. |
| Google HK | Google-style coverage from HK endpoint | May trigger anti-bot; fetch sparingly. |
| Brave | Independent index | Useful when mainstream engines are noisy. |
| Startpage | Google-like results via privacy proxy | Can be fragile to scrape. |
| Yahoo | Additional mainstream coverage | Mainly for second-opinion checks. |
| Ecosia / Qwant | Alternative indexes / EU-oriented coverage | Use when diversity matters. |
| WolframAlpha | Computation and structured facts | Not a web-result engine; use for math/conversion/knowledge queries. |

## Common query patterns

- Exact phrase: `"quoted phrase"`
- Site search: `site:example.com keyword`
- Repository search fallback: `site:github.com org repo keyword`
- File search: `filetype:pdf annual report`
- Recent results on Google-compatible URLs: append `&tbs=qdr:w` for past week.

## Workflow

1. Generate 2-3 candidate search URLs with the script.
2. Fetch only the most promising search result page(s).
3. Extract full pages with `web-scrape` after URLs are discovered.
4. For important claims, compare at least two independent sources.
