#!/bin/bash

# Usage: ./script.sh <filename> [-m "custom commit message"]

FILE=""
CUSTOM_MESSAGE=""

# Argument parsing
while [[ $# -gt 0 ]]; do
  case "$1" in
  -m | --message)
    CUSTOM_MESSAGE="$2"
    shift 2
    ;;
  *)
    if [[ -z "$FILE" ]]; then
      FILE="$1"
    else
      echo "Unexpected argument: $1"
      exit 1
    fi
    shift
    ;;
  esac
done

if [ -z "$FILE" ]; then
  echo "Usage: $0 <filename> [-m \"custom commit message\"]"
  exit 1
fi

if [ ! -f "$FILE" ]; then
  echo "File '$FILE' does not exist."
  exit 1
fi

BASENAME=$(basename "$FILE")

# Find all version numbers in commit messages for this file
VERSIONS=$(git log --pretty=%s -- "$FILE" | grep -oE 'v([0-9]+)\.([0-9]+)\.([0-9]+)' | sed 's/^v//' || true)

HIGHEST_MAJOR=1
HIGHEST_MINOR=0
HIGHEST_PATCH=0

if [[ -n "$VERSIONS" ]]; then
  while read -r VERSION; do
    MAJOR=$(echo "$VERSION" | cut -d. -f1)
    MINOR=$(echo "$VERSION" | cut -d. -f2)
    PATCH=$(echo "$VERSION" | cut -d. -f3)

    # Compare version numbers
    if ((MAJOR > HIGHEST_MAJOR)) ||
      ((MAJOR == HIGHEST_MAJOR && MINOR > HIGHEST_MINOR)) ||
      ((MAJOR == HIGHEST_MAJOR && MINOR == HIGHEST_MINOR && PATCH > HIGHEST_PATCH)); then
      HIGHEST_MAJOR=$MAJOR
      HIGHEST_MINOR=$MINOR
      HIGHEST_PATCH=$PATCH
    fi
  done <<<"$VERSIONS"
fi

# Increment minor version, reset patch to 0
NEW_MAJOR=$HIGHEST_MAJOR
NEW_MINOR=$((HIGHEST_MINOR + 1))
NEW_PATCH=0

NEW_VERSION="$NEW_MAJOR.$NEW_MINOR.$NEW_PATCH"
DATE=$(date '+%Y-%m-%d')

# Compose commit message
if [ -n "$CUSTOM_MESSAGE" ]; then
  MESSAGE="$CUSTOM_MESSAGE - v$NEW_VERSION"
else
  MESSAGE="$DATE - $BASENAME - v$NEW_VERSION"
fi

git add "$FILE"
git commit -m "$MESSAGE"
git push

echo "Committed and pushed '$FILE' as version v$NEW_VERSION"
