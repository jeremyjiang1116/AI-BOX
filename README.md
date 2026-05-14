# AI-BOX

AI-BOX is a collection of reusable OpenClaw skills, workflow assets, and agent collaboration utilities.

This repository is intended to be an index and distribution home for skills. Each skill keeps its detailed usage guide inside its own `SKILL.md` and `references/` files.

## Included skills

| Skill | Purpose | Notes |
| --- | --- | --- |
| [`web-research/`](./web-research/) | Web research and search routing | Routes general search, Chinese web/WeChat discovery, fact checking, GitHub/source lookup, and known-URL handoff. |
| [`web-scrape/`](./web-scrape/) | Readable content extraction from URLs | Fetches and extracts pages, supports site strategies, Playwright fallback, and WeChat official account articles. |
| [`discord-visible-multiagent/`](./discord-visible-multiagent/) | Visible Discord multi-agent workflow | Coordinates HQ/executor collaboration with round labels, review loops, and fallback handling. |

## Repository layout

```text
AI-BOX/
├── web-research/
│   ├── SKILL.md
│   ├── scripts/
│   └── references/
├── web-scrape/
│   ├── SKILL.md
│   ├── scripts/
│   └── references/
└── discord-visible-multiagent/
    ├── SKILL.md
    ├── scripts/
    └── references/
```

## How to use

1. Pick the skill directory that matches the task.
2. Read that directory's `SKILL.md` first.
3. Use files under `references/` only when the skill asks for deeper workflow details.
4. Keep generated artifacts, caches, local environment files, and secrets out of the repository.

## Local development

Run repository sanity checks with Node 18+ and Bash:

```bash
npm run check
```

For JavaScript-only syntax checks:

```bash
npm run check:js
```

Install `web-scrape` Python dependencies in an isolated environment:

```bash
python3 -m venv .venv-web
. .venv-web/bin/activate
pip install -r web-scrape/requirements.txt
python -m playwright install chromium
```

## Skill summaries

### `web-research`

Use this when a task needs web research, current information, source discovery, fact checking, Chinese web search, WeChat article discovery, GitHub/source search, or search URL generation.

It acts as the routing gate for research workflows and delegates known URL extraction to `web-scrape`.

### `web-scrape`

Use this when a task already has a URL and needs readable page content extracted.

It supports static HTML fetch, mobile fallback, Playwright-rendered pages, site-specific strategies, API endpoint discovery, and WeChat official account article extraction.

### `discord-visible-multiagent`

Use this when a task needs visible, reviewable, multi-round collaboration across Discord channels or threads.

The root README intentionally does not duplicate the full workflow. See [`discord-visible-multiagent/SKILL.md`](./discord-visible-multiagent/SKILL.md) and its `references/` directory for the complete process.

## Maintenance notes

- Do not commit secrets or API keys. Runtime integrations should read credentials from environment variables.
- Do not commit generated files such as `__pycache__/`, `*.pyc`, packaged `.skill` files, or local virtual environments.
- Keep root-level documentation concise. Put skill-specific details in the corresponding skill directory.
