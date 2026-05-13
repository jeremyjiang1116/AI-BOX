#!/usr/bin/env node
import { spawnSync } from 'node:child_process';
import fs from 'node:fs';
import path from 'node:path';

function usage() {
  console.error(`Usage:
  node scripts/route-search.mjs --query "..." [--mode auto|general|cn|verify|github|url] [--count 5] [--json]

Modes:
  auto     -> choose a route from query heuristics
  general  -> Tavily when available, otherwise OpenClaw web_search
  cn       -> bundled CN / WeChat discovery URLs
  verify   -> primary search plus cross-check URLs
  github   -> GitHub repository/source discovery
  url      -> existing URL content extraction via sibling web-scrape
`);
  process.exit(2);
}

const args = process.argv.slice(2);
let query = '';
let mode = 'auto';
let count = 5;
let json = false;
for (let i = 0; i < args.length; i++) {
  const a = args[i];
  if (a === '--query') { query = args[++i] ?? ''; continue; }
  if (a === '--mode') { mode = (args[++i] ?? 'auto').toLowerCase(); continue; }
  if (a === '--count') { count = Number.parseInt(args[++i] ?? '5', 10); continue; }
  if (a === '--json') { json = true; continue; }
  if (a === '-h' || a === '--help') usage();
  console.error(`Unknown arg: ${a}`);
  usage();
}
if (!query) usage();
if (!Number.isFinite(count) || count < 1) count = 5;

const scriptDir = path.dirname(new URL(import.meta.url).pathname);
const skillDir = path.resolve(scriptDir, '..');
const skillsDir = path.resolve(skillDir, '..');
const tavilyScript = path.resolve(skillDir, 'scripts/tavily-search.mjs');
const multiScript = path.resolve(skillDir, 'scripts/build-search-url.mjs');
const webScrapeScript = path.resolve(skillsDir, 'web-scrape/scripts/fetch-url.py');

function tavilyAvailable() {
  return fs.existsSync(tavilyScript) && Boolean((process.env.TAVILY_API_KEY ?? '').trim());
}

function multiAvailable() {
  return fs.existsSync(multiScript);
}

function webScrapeAvailable() {
  return fs.existsSync(webScrapeScript);
}

function hasHan(q) {
  return Array.from(q).some(ch => {
    const code = ch.codePointAt(0) ?? 0;
    return code >= 0x4e00 && code <= 0x9fff;
  });
}

function isUrl(q) {
  try {
    const u = new URL(q.trim());
    return u.protocol === 'http:' || u.protocol === 'https:';
  } catch {
    return false;
  }
}

function detectMode(q) {
  if (isUrl(q)) return 'url';
  if (/(github|repo|repository|仓库|源码|source code|source repo)/i.test(q)) return 'github';
  if (/(微信|公众号|weixin|wechat|搜狗微信|中文互联网|国内|百度|搜狗|头条)/i.test(q)) return 'cn';
  if (/(核实|查证|verify|fact check|cross.?check|真假|是否属实|辟谣)/i.test(q)) return 'verify';
  if (hasHan(q) && /(文章|资讯|新闻|官网|社区|论坛)/.test(q)) return 'cn';
  return 'general';
}

function buildMulti(modeName) {
  if (!multiAvailable()) return { urls: {}, error: 'bundled build-search-url.mjs not found' };
  const child = spawnSync(process.execPath, [multiScript, '--query', query, '--mode', modeName, '--json'], {
    encoding: 'utf8',
    env: process.env,
  });
  if (child.status !== 0) {
    return { urls: {}, error: (child.stderr || child.stdout || '').trim() || `build-search-url.mjs exited ${child.status}` };
  }
  try {
    const parsed = JSON.parse(child.stdout);
    return { urls: parsed.urls || {}, engines: parsed.engines || [] };
  } catch (err) {
    return { urls: {}, error: `failed to parse build-search-url.mjs output: ${err.message}` };
  }
}

function baseDecision(taskType, backend, why) {
  return {
    task_type: taskType,
    mode,
    backend,
    query,
    count,
    why,
    next_action: '',
    fallbacks: [],
    urls: {},
    notes: [],
    availability: {
      tavily: tavilyAvailable(),
      multi_engine_urls: multiAvailable(),
      web_scrape: webScrapeAvailable(),
      web_search_tool: true,
    },
  };
}

function emit(decision) {
  if (json) {
    console.log(JSON.stringify(decision, null, 2));
    return;
  }
  console.log('# Web Research Decision\n');
  for (const [k, v] of Object.entries(decision)) {
    if (Array.isArray(v)) console.log(`${k}: ${v.join('; ')}`);
    else if (v && typeof v === 'object') console.log(`${k}: ${JSON.stringify(v)}`);
    else console.log(`${k}: ${v}`);
  }
}

if (mode === 'auto') mode = detectMode(query);

if (mode === 'general') {
  const backend = tavilyAvailable() ? 'web-research/tavily' : 'web_search';
  const decision = baseDecision('search', backend, tavilyAvailable()
    ? 'General research prefers Tavily when installed and keyed.'
    : 'Tavily is unavailable; use the first-class OpenClaw web_search tool as the deterministic fallback.');
  decision.next_action = tavilyAvailable()
    ? `run web-research/scripts/tavily-search.mjs with count=${count}, then fetch high-value result URLs with web-scrape if full text is needed`
    : `call web_search(query=${JSON.stringify(query)}, count=${Math.min(count, 10)}), then fetch high-value result URLs with web-scrape if full text is needed`;
  decision.fallbacks = [
    'web-research/scripts/build-search-url.mjs --mode global for another public-search angle',
    'simplify or broaden the query',
    'use web-scrape on known primary-source URLs',
  ];
  emit(decision);
  process.exit(0);
}

if (mode === 'cn') {
  const multi = buildMulti(/(微信|公众号|weixin|wechat|搜狗微信)/i.test(query) ? 'wechat' : 'cn');
  const decision = baseDecision('search', 'web-research/multi-engine', 'Chinese web / WeChat / CN coverage needs engines that generic global search often misses.');
  decision.urls = multi.urls;
  decision.engines = multi.engines || [];
  decision.next_action = 'open/fetch one or more listed search URLs; use web-scrape for result pages that need full extraction';
  decision.fallbacks = ['web_search for broad global context', 'web-research/scripts/build-search-url.mjs --mode global for cross-region comparison'];
  if (multi.error) decision.notes.push(multi.error);
  emit(decision);
  process.exit(multi.error ? 1 : 0);
}

if (mode === 'verify') {
  const multi = buildMulti('verify');
  const backend = tavilyAvailable() ? 'web-research/tavily + multi-engine' : 'web_search + web-research/multi-engine';
  const decision = baseDecision('verify', backend, 'Verification should combine a primary search path with independent public-search cross-checks.');
  decision.urls = multi.urls;
  decision.engines = multi.engines || [];
  decision.next_action = tavilyAvailable()
    ? `run Tavily with count=${count}; then compare against listed cross-check URLs`
    : `call web_search(query=${JSON.stringify(query)}, count=${Math.min(count, 10)}); then compare against listed cross-check URLs`;
  decision.fallbacks = ['fetch primary-source URLs with web-scrape', 'try CN mode if the claim is China-specific'];
  if (multi.error) decision.notes.push(multi.error);
  emit(decision);
  process.exit(multi.error ? 1 : 0);
}

if (mode === 'github') {
  const decision = baseDecision('search', 'github-search', 'Repository/source discovery should start from GitHub-specific search, not generic result pages.');
  decision.urls = {
    repositories: `https://github.com/search?q=${encodeURIComponent(query)}&type=repositories`,
    code: `https://github.com/search?q=${encodeURIComponent(query)}&type=code`,
  };
  decision.next_action = 'use the GitHub skill/gh CLI when available; otherwise fetch the listed GitHub search URLs';
  decision.fallbacks = ['web_search with site:github.com', 'web-research/scripts/build-search-url.mjs --mode global'];
  emit(decision);
  process.exit(0);
}

if (mode === 'url') {
  const decision = baseDecision('scrape', 'web-scrape', 'The input is already a URL; search is unnecessary.');
  decision.urls = { target: query.trim() };
  decision.next_action = webScrapeAvailable()
    ? `run web-scrape/scripts/fetch-url.py --url ${JSON.stringify(query.trim())} --strategy html-fetch --json; escalate to playwright/mobile-fetch only if needed`
    : 'use web_fetch as a lightweight fallback; restore web-scrape for robust extraction';
  decision.fallbacks = ['web_fetch for simple static pages', 'playwright strategy for JS shells', 'mobile-fetch for simple anti-bot pages'];
  emit(decision);
  process.exit(0);
}

console.error(`Unsupported mode: ${mode}`);
process.exit(2);
