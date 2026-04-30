#!/usr/bin/env python3
import json
import sys

payload = json.load(sys.stdin)

errors = []
if not isinstance(payload, dict):
    errors.append("payload_not_object")
else:
    if payload.get("label") != " ":
        errors.append("label_must_equal_single_space")
    if not payload.get("sessionKey"):
        errors.append("missing_sessionKey")
    if not payload.get("message"):
        errors.append("missing_message")
    contract = payload.get("contract") or {}
    if contract.get("selector_mode") != "sessionKey_plus_whitespace_label":
        errors.append("selector_mode_mismatch")
    if contract.get("manual_shape_changes_forbidden") is not True:
        errors.append("manual_shape_changes_flag_missing")
    if contract.get("freeform_label_forbidden") is not True:
        errors.append("freeform_label_flag_missing")

if errors:
    print(json.dumps({"ok": False, "errors": errors}, ensure_ascii=False, indent=2))
    sys.exit(1)

print(json.dumps({"ok": True}, ensure_ascii=False, indent=2))
