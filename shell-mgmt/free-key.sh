#!/bin/bash

DB_PATH="$HOME/Projects/API-Key/github.db"
LIVEKEY_PATH="$HOME/Projects/API-Key/LiveKey"

# 1. Get an unused API key
api_key=$(sqlite3 "$DB_PATH" "SELECT apiKey FROM APIKeys WHERE status = 'yes' LIMIT 1;")

if [ -z "$api_key" ]; then
  echo "No unused API key found."
  exit 1
fi

# 2. Write the key to the file
echo -n "$api_key" >"$LIVEKEY_PATH"

# 3. Delete the key from the database
sqlite3 "$DB_PATH" "DELETE FROM APIKeys WHERE apiKey = '$api_key';"

# 4. Source .bashrc
# (This will only affect the current shell session, so you'd need to run this script as '. script.sh' or 'source script.sh' to have it update your environment)
source ~/.bashrc

echo "Key retrieved and set - $(OPENAI_API_KEY)"
