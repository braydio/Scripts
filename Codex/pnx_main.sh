#!/usr/bin/env bash

# pnx: Codex + ChromaDB helper for pyNance

PY_SCRIPT_DIR="$HOME/Projects/pyNance/scripts"
CHROMA_HOST="localhost"
CHROMA_PORT="8055"

case "$1" in
embed)
  echo "📦 Embedding backend code into ChromaDB..."
  python3 "$PY_SCRIPT_DIR/embed_backend.py"
  ;;

ask)
  QUERY="${2:-What does pyNance do?}"
  echo "🧠 Asking: $QUERY"
  python3 "$PY_SCRIPT_DIR/query_backend.py" "$QUERY"
  ;;

grep)
  TERM="${2:-AccountHistory}"
  echo "🔍 Searching stored embeddings for: $TERM"
  python3 "$PY_SCRIPT_DIR/query_backend.py" "$TERM" | grep --color=always -C 2 "$TERM"
  ;;

*)
  echo "Usage: pnx [embed|ask \"your question\"|grep \"term\"]"
  ;;
esac
