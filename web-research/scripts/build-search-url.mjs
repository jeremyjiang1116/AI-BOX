#!/usr/bin/env node
import fs from 'node:fs';
import path from 'node:path';

const scriptDir = path.dirname(new URL(import.meta.url).pathname);
const skillDir = path.resolve(scriptDir, '..');
const enginesPath = path.join(skillDir, 'references', 'engines.json');

function loadEngines() {
  const parsed = JSON.parse(fs.readFileSync(enginesPath, 'utf8'));
  if (!Array.isArray(parsed.engines)) throw new Error('references/engines.json must contain an engines array');
  return parsed.engines;
}

const ENGINES = loadEngines();

function usage() {
  console.error(`Usage:
  node scripts/build-search-url.mjs --query "..." [--engine name] [--mode cn|global|verify|wechat] [--json]

Examples:
  node scripts/build-search-url.mjs --query "AI agent 公众号" --mode cn --json
  node scripts/build-search-url.mjs --query "openclaw" --engine DuckDuckGo --json
`);
  process.exit(2);
}

const args = process.argv.slice(2);
let query = '';
let engine = '';
let mode = '';
let json = false;
for (let i = 0; i < args.length; i++) {
  const a = args[i];
  if (a === '--query') { query = args[++i] ?? ''; continue; }
  if (a === '--engine') { engine = args[++i] ?? ''; continue; }
  if (a === '--mode') { mode = (args[++i] ?? '').toLowerCase(); continue; }
  if (a === '--json') { json = true; continue; }
  if (a === '-h' || a === '--help') usage();
  console.error(`Unknown arg: ${a}`);
  usage();
}
if (!query) usage();
if (!engine && !mode) mode = 'global';

const aliases = new Map(
  ENGINES.flatMap(e => (e.aliases || []).map(alias => [alias.toLowerCase(), e.name]))
);

function canonicalEngineName(name) {
  if (!name) return '';
  const key = name.toLowerCase();
  return aliases.get(key) || name;
}

function getEngine(name) {
  const canonical = canonicalEngineName(name);
  const found = ENGINES.find(e => e.name.toLowerCase() === canonical.toLowerCase());
  if (!found) throw new Error(`unknown engine: ${name}`);
  return found;
}

function buildUrl(e, q) {
  return e.url.replace('{keyword}', encodeURIComponent(q));
}

function modeEngines(m) {
  if (m === 'wechat') return ['WeChat', 'Sogou'];
  if (m === 'cn') return ['WeChat', 'Sogou', 'Baidu', 'Bing CN'];
  if (m === 'verify') return ['Bing INT', 'DuckDuckGo', 'Google HK'];
  if (m === 'global') return ['DuckDuckGo', 'Bing INT', 'Google HK'];
  throw new Error(`unknown mode: ${m}`);
}

try {
  const selected = engine ? [getEngine(engine)] : modeEngines(mode).map(getEngine);
  const urls = Object.fromEntries(selected.map(e => [e.name, buildUrl(e, query)]));
  const out = {
    task_type: 'search',
    backend: 'web-research/multi-engine',
    query,
    mode: engine ? 'single-engine' : mode,
    engines: selected.map(e => e.name),
    urls,
    next_action: 'fetch one or more URLs, then use web-scrape for full-page extraction when needed',
    fallbacks: ['try another listed engine', 'simplify query', 'route through web-research for broader research'],
    notes: 'URL generator only; it does not fetch or rank results.',
  };
  if (json) {
    console.log(JSON.stringify(out, null, 2));
  } else {
    for (const [name, url] of Object.entries(urls)) console.log(`${name}: ${url}`);
  }
} catch (err) {
  const message = err instanceof Error ? err.message : String(err);
  if (json) {
    console.log(JSON.stringify({ task_type: 'search', backend: 'web-research/multi-engine', error: message }, null, 2));
  } else {
    console.error(message);
  }
  process.exit(1);
}
