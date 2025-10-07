#!/bin/bash
if ! command -v enry &>/dev/null; then
  echo "Please install enry first."
  exit 1
fi

TOP_LANG=$(enry . | sort | uniq -c | sort -rn | head -n 1 | awk '{print $2}')
PROFILE="generic"

case "$TOP_LANG" in
TypeScript | JavaScript)
  if grep -q tailwind.config ./*; then
    PROFILE="vue-tailwind"
  else
    PROFILE="js-default"
  fi
  ;;
Python)
  if grep -q fastapi pyproject.toml 2>/dev/null; then
    PROFILE="fastapi"
  else
    PROFILE="python-minimal"
  fi
  ;;
Lua)
  PROFILE="neovim-plugin"
  ;;
esac

echo "$PROFILE" >.nvim-profile
echo "Wrote profile: $PROFILE"
