
#!/bin/bash

FILE="$1"

if [ -z "$FILE" ]; then
  echo "Usage: $0 <filename>"
  exit 1
fi

if [ ! -f "$FILE" ]; then
  echo "File '$FILE' does not exist."
  exit 1
fi

BASENAME=$(basename "$FILE")

# Fetch latest commit for the file
LATEST_COMMIT_MSG=$(git log -1 --pretty=%s -- "$FILE")

# Extract version number from commit message
if [[ $LATEST_COMMIT_MSG =~ ([0-9]+)\.([0-9]+)\.([0-9]+)$ ]]; then
  CURRENT_MAJOR=${BASH_REMATCH[1]}
  CURRENT_MINOR=${BASH_REMATCH[2]}
  CURRENT_PATCH=${BASH_REMATCH[3]}
  CURRENT_MINOR=$((CURRENT_MINOR + 1))  # Increment minor (10th position)
else
  CURRENT_MAJOR=1
  CURRENT_MINOR=0
  CURRENT_PATCH=0
fi

NEW_VERSION="$CURRENT_MAJOR.$CURRENT_MINOR.$CURRENT_PATCH"
DATE=$(date '+%Y-%m-%d')

MESSAGE="$DATE - $BASENAME - v$CURRENT_MAJOR.$CURRENT_MINOR.$CURRENT_PATCH"

git add "$FILE"
git commit -m "$MESSAGE"
git push

echo "Committed and pushed '$FILE' as version v${CURRENT_MAJOR}.${CURRENT_MINOR}.${CURRENT_PATCH}"

