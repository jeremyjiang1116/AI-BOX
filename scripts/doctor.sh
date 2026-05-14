#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

printf '== JavaScript syntax ==\n'
node --check web-research/scripts/*.mjs

printf '\n== Shell syntax ==\n'
for f in discord-visible-multiagent/scripts/*.sh scripts/*.sh; do
  bash -n "$f"
done
printf 'shell syntax ok\n'

printf '\n== Python syntax ==\n'
python3 - <<'PY'
import ast
from pathlib import Path
paths = sorted(Path('.').glob('web-scrape/scripts/*.py')) + sorted(Path('.').glob('discord-visible-multiagent/scripts/*.py'))
for path in paths:
    ast.parse(path.read_text(), filename=str(path))
    print(f'{path}: ok')
PY

printf '\n== discord-visible-multiagent regressions ==\n'
for t in \
  discord-visible-multiagent/scripts/test_visible_contract_integrity.sh \
  discord-visible-multiagent/scripts/test_handoff_runtime_contract.sh \
  discord-visible-multiagent/scripts/test_runtime_truth_regressions.sh
 do
  printf -- '--- %s ---\n' "$t"
  bash "$t"
done

printf '\nDoctor checks passed.\n'
