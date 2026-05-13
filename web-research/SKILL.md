---
name: web-research
description: Route web research, current-info lookup, fact-checking, source discovery, Chinese web and WeChat article discovery, GitHub/source search, and search URL generation. Prefer bundled Tavily when installed and keyed; use web_search as fallback; hand direct URL extraction to web-scrape.
---

# Web Research

Use this skill as the routing gate for search and research tasks. It replaces the old `search-router`, `multi-search-engine`, and `tavily-search` skills.

For direct URL fetching, page parsing, or article extraction where the URL is already known, use `web-scrape` directly unless routing context is needed. Known `mp.weixin.qq.com/s/...` article URLs also go to `web-scrape`; it auto-selects its embedded WeChat MP reader.

## Hard gate

- For web research, fact-checking, current information, article discovery, source discovery, repo discovery, or technical lookup, enter this skill before choosing a backend.
- Do not default to generic `web_search` by habit. Run the router first, then follow its output.
- If Tavily is unavailable, use the router's explicit `web_search` fallback.
- After search result discovery, use `web-scrape` only for high-value URLs that need full text.

## Router entrypoint

```bash
node scripts/route-search.mjs --query "..." --json
node scripts/route-search.mjs --query "..." --mode auto --json
node scripts/route-search.mjs --query "..." --mode general --json
node scripts/route-search.mjs --query "..." --mode cn --json
node scripts/route-search.mjs --query "..." --mode verify --json
node scripts/route-search.mjs --query "..." --mode github --json
```

Modes:
- `auto` — default; choose from query heuristics.
- `general` — Tavily if available, otherwise first-class `web_search`.
- `cn` — Chinese web / WeChat / Sogou Weixin discovery URLs.
- `verify` — primary search plus independent cross-check URLs.
- `github` — GitHub repository/source discovery URLs.
- `url` — route a known URL to sibling `web-scrape`.

## Bundled executables

### Tavily search

Use only when `TAVILY_API_KEY` is set.

```bash
node scripts/tavily-search.mjs "query" -n 5
node scripts/tavily-search.mjs "query" --deep
node scripts/tavily-search.mjs "query" --topic news --days 7
```

### Tavily extract

```bash
node scripts/tavily-extract.mjs "https://example.com/article"
```

### Multi-engine URL generation

Generates URLs only; it does not fetch or rank results.

```bash
node scripts/build-search-url.mjs --query "..." --mode cn --json
node scripts/build-search-url.mjs --query "..." --mode wechat --json
node scripts/build-search-url.mjs --query "..." --mode global --json
node scripts/build-search-url.mjs --query "..." --mode verify --json
node scripts/build-search-url.mjs --query "..." --engine DuckDuckGo --json
```

Modes:
- `wechat`: WeChat, Sogou.
- `cn`: WeChat, Sogou, Baidu, Bing CN.
- `global`: DuckDuckGo, Bing INT, Google HK.
- `verify`: Bing INT, DuckDuckGo, Google HK.

Engine aliases include: `baidu`, `bing-cn`, `bing-int`, `wechat`, `weixin`, `google`, `google-hk`, `duckduckgo`, `ddg`, `brave`, `wolfram`.

## Routing rules

- General research / technical lookup → router `general`; use Tavily when keyed, else `web_search`.
- Chinese web / 微信 / 公众号 / 搜狗微信 / 国内搜索补盲 → router `cn`.
- Important or controversial claims → router `verify`, then compare sources.
- Known URL content extraction → `web-scrape`; known `mp.weixin.qq.com/s/...` article URLs are not a separate skill anymore.
- GitHub/source discovery → router `github`, then use GitHub/gh tools when useful.

## Cost control

1. Start with one search path.
2. Start small: low result count first.
3. Fetch full pages only when snippets or search results are insufficient.
4. Treat Tavily quota as limited; preserve it for synthesis-heavy or high-value research.
5. For WeChat/CN article discovery, prefer bundled multi-engine URLs first.

## References

- `references/engines.json` — canonical engine URL templates and aliases.
- `references/advanced-search.md` — compact operators and search patterns.
- `references/international-search.md` — global engine selection notes.
