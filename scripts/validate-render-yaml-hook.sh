#!/usr/bin/env bash
set -uo pipefail

# Claude Code hook: validate render.yaml after Edit/Write/MultiEdit.
#
# Reads the tool-call JSON payload from stdin, extracts tool_input.file_path,
# and runs `render blueprints validate` from that file's directory when the
# touched file is a render.yaml (or render.yml). Exits 0 on no-op so it never
# blocks unrelated edits.

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

if ! command -v render &>/dev/null; then
  echo "[render plugin] Render CLI not found. Install it to validate render.yaml:"
  echo "  macOS:  brew install render"
  echo "  Linux:  curl -fsSL https://raw.githubusercontent.com/render-oss/cli/main/bin/install.sh | sh"
  exit 0
fi

DIR="$(dirname "$FILE_PATH")"
if [[ ! -d "$DIR" ]]; then
  exit 0
fi

(cd "$DIR" && render blueprints validate)
