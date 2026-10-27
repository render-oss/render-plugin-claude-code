#!/usr/bin/env bash
set -uo pipefail

# Claude Code hook: suggest validating render.yaml after Edit/Write/MultiEdit.
#
# Reads the tool-call JSON payload from stdin, extracts tool_input.file_path,
# and, when the touched file is a render.yaml (or render.yml), asks Claude to
# run `render blueprints validate` on it. The hook never runs the Render CLI
# itself: validation uses the user's Render login, so it goes through the
# user's normal Bash approval. Exits 0 on no-op so it never blocks edits.

INPUT="$(cat 2>/dev/null || true)"
if [[ -z "$INPUT" ]]; then
  exit 0
fi

extract_file_path() {
  local payload="$1"
  if command -v python3 &>/dev/null; then
    python3 - "$payload" <<'PY' 2>/dev/null
import json, sys
try:
    data = json.loads(sys.argv[1])
except Exception:
    sys.exit(0)
ti = data.get("tool_input") or {}
fp = ti.get("file_path") or ti.get("filePath") or ""
if isinstance(fp, str):
    print(fp)
PY
  else
    printf '%s' "$payload" | sed -n 's/.*"file_path"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -n 1
  fi
}

FILE_PATH="$(extract_file_path "$INPUT")"

if [[ -z "$FILE_PATH" ]]; then
  exit 0
fi

BASENAME="$(basename "$FILE_PATH")"
case "$BASENAME" in
  render.yaml|render.yml) ;;
  *) exit 0 ;;
esac

CONTEXT="[render plugin] $FILE_PATH changed. Validate it by running \`render blueprints validate $FILE_PATH\` and fix any errors it reports. If the Render CLI is not installed, see https://render.com/docs/cli#1-install-or-upgrade."

# Escape for a JSON string: backslashes first, then quotes.
CONTEXT="${CONTEXT//\\/\\\\}"
CONTEXT="${CONTEXT//\"/\\\"}"

printf '{"hookSpecificOutput":{"hookEventName":"PostToolUse","additionalContext":"%s"}}\n' "$CONTEXT"
