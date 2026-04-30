#!/usr/bin/env python3
"""Helpers for discovering OpenClaw executor account bindings.

This module intentionally avoids hard-coded host-specific absolute paths.
Set OPENCLAW_HOME when running outside the default user home.
"""
from __future__ import annotations

import json
import os
from pathlib import Path
from typing import Any


def openclaw_home() -> Path:
    return Path(os.environ.get("OPENCLAW_HOME", str(Path.home() / ".openclaw"))).expanduser()


def sessions_path_for_agent(agent_id: str) -> Path:
    return openclaw_home() / "agents" / agent_id / "sessions" / "sessions.json"


def discover_account_binding(agent_id: str) -> dict[str, Any]:
    """Return account binding discovery result for an executor agent.

    ok=True means exactly one bound account was discovered.
    ok=False includes an error code and non-secret evidence useful for BLOCKED reporting.
    """
    sessions_path = sessions_path_for_agent(agent_id)
    public_source = "${OPENCLAW_HOME:-~/.openclaw}/agents/<agent>/sessions/sessions.json"
    if not sessions_path.exists():
        return {
            "ok": False,
            "error": "executor_sessions_missing",
            "account_id": "",
            "evidence": {"source": public_source, "exists": False},
            "source": public_source,
        }

    try:
        sessions_obj = json.loads(sessions_path.read_text())
    except Exception as exc:  # pragma: no cover - exercised by shell-level callers
        return {
            "ok": False,
            "error": "executor_sessions_parse_failed",
            "account_id": "",
            "evidence": {"source": public_source, "error": str(exc)},
            "source": public_source,
        }

    candidates = []
    for session_key, meta in sessions_obj.items():
        if not isinstance(meta, dict):
            continue
        origin = meta.get("origin") or {}
        delivery = meta.get("deliveryContext") or {}
        for label, value in [
            ("origin.accountId", origin.get("accountId")),
            ("deliveryContext.accountId", delivery.get("accountId")),
            ("lastAccountId", meta.get("lastAccountId")),
        ]:
            if value:
                candidates.append((label, value, session_key))

    uniq = sorted(set(value for _, value, _ in candidates))
    if len(uniq) == 1:
        account_id = uniq[0]
        return {
            "ok": True,
            "error": "",
            "account_id": account_id,
            "evidence": [
                {"source": label, "value": value, "sessionKey": session_key}
                for label, value, session_key in candidates
                if value == account_id
            ],
            "source": public_source,
        }
    if len(uniq) > 1:
        return {
            "ok": False,
            "error": "executor_account_binding_ambiguous",
            "account_id": "",
            "candidate_accounts": uniq,
            "evidence": [
                {"source": label, "value": value, "sessionKey": session_key}
                for label, value, session_key in candidates
            ],
            "source": public_source,
        }
    return {
        "ok": False,
        "error": "executor_account_binding_missing",
        "account_id": "",
        "evidence": {"source": public_source, "exists": True},
        "source": public_source,
    }
