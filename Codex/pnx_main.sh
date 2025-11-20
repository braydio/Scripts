#!/usr/bin/env bash

# pnx: Codex + ChromaDB helper for pyNance

PY_SCRIPT_DIR="$HOME/Projects/pyNance/scripts"

resolve_python3() {
  if [ -x /usr/bin/python3 ]; then echo /usr/bin/python3; return; fi
  local p
  p=$(command -v python3 2>/dev/null || true)
  case "$p" in */.pyenv/shims/*) p="";; esac
  if [ -n "$p" ]; then echo "$p"; return; fi
  p=$(command -v python 2>/dev/null || true)
  if [ -n "$p" ] && "$p" -V 2>&1 | grep -q "Python 3"; then echo "$p"; return; fi
  echo python3
}
PY3_BIN=$(resolve_python3)
CHROMA_HOST="localhost"
CHROMA_PORT="8055"

case "$1" in
embed)
  echo "📦 Embedding backend code into ChromaDB..."
  "$PY3_BIN" "$PY_SCRIPT_DIR/embed_backend.py"
  ;;

ask)
  QUERY="${2:-What does pyNance do?}"
  echo "🧠 Asking: $QUERY"
  "$PY3_BIN" "$PY_SCRIPT_DIR/query_backend.py" "$QUERY"
  ;;

grep)
  TERM="${2:-AccountHistory}"
  echo "🔍 Searching stored embeddings for: $TERM"
  "$PY3_BIN" "$PY_SCRIPT_DIR/query_backend.py" "$TERM" | grep --color=always -C 2 "$TERM"
  ;;

*)
  echo "Usage: pnx [embed|ask \"your question\"|grep \"term\"]"
  ;;
esac
