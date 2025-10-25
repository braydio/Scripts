#!/usr/bin/env bash

FILE="ToDo.md"
TEMPLATE=$(
  cat <<EOF

### 📝 To-Do

- [ ] **Title**: 
- [ ] **Context**: 
- [ ] **Steps**:
  - [ ] Step 1
  - [ ] Step 2
- [ ] **Deadline**:

EOF
)

# Create file with initial template if not present
if [ ! -f "$FILE" ]; then
  echo "$TEMPLATE" >"$FILE"
  nvim "$FILE"
  exit 0
fi

# Check if last todo is filled (very basic check: is Title empty?)
if tail -n 20 "$FILE" | grep -q '\*\*Title\*\*: *$'; then
  nvim "$FILE"
  exit 0
fi

# Append new todo block
echo "$TEMPLATE" >>"$FILE"
nvim "$FILE"
