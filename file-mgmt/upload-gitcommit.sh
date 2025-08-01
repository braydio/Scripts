
#!/bin/bash

# Backup system files to a Git directory for versioning
# Repurposed from the FileAggredizer script

# Script metadata
SCRIPT_NAME="UpDotGit"
SCRIPT_VERSION="1.0"

# Print script name and version
echo -e "\e[34m$SCRIPT_NAME - Version $SCRIPT_VERSION\e[0m"
echo

# Define directories
GIT_BACKUP_DIR="$HOME/Uploads/Github/dotfiles"
CONFIG_FILE="$HOME/Scripts/file-mgmt/dotgit-files.txt"
LOG_FILE="$GIT_BACKUP_DIR/backup_failures.log"

# Create Git backup directory if it doesn't exist
mkdir -p "$GIT_BACKUP_DIR"

# Initialize log file
> "$LOG_FILE"

# Check if the config file exists
if [ ! -f "$CONFIG_FILE" ]; then
    echo -e "\e[31mError: Config file '$CONFIG_FILE' not found.\e[0m"
    exit 1
fi

# Counters for success and failure
success_count=0
failure_count=0

# Process each file or directory from the config file
while IFS= read -r ENTRY; do
    # Skip empty lines and comments
    [[ -z "$ENTRY" || "$ENTRY" == \#* ]] && continue

    # Expand tilde and variables
    ENTRY=$(eval echo "$ENTRY")

    # Validate the file or directory
    if [ -f "$ENTRY" ]; then
        DEST="$GIT_BACKUP_DIR/${ENTRY#$HOME/}"
        mkdir -p "$(dirname "$DEST")"
        if cp "$ENTRY" "$DEST" 2>/dev/null; then
            echo -e "\e[32mCopied $ENTRY to $DEST\e[0m"
            ((success_count++))
        else
            echo -e "\e[31mFailed to copy $ENTRY to $DEST\e[0m" | tee -a "$LOG_FILE"
            ((failure_count++))
        fi
    elif [ -d "$ENTRY" ]; then
        find -L "$ENTRY" -type f -print | while IFS= read -r FILE; do
            DEST="$GIT_BACKUP_DIR/${FILE#$HOME/}"
            mkdir -p "$(dirname "$DEST")"
            if cp "$FILE" "$DEST" 2>/dev/null; then
                echo -e "\e[32mCopied $FILE to $DEST\e[0m"
                ((success_count++))
            else
                echo -e "\e[31mFailed to copy $FILE to $DEST\e[0m" | tee -a "$LOG_FILE"
                ((failure_count++))
            fi
        done
    else
        echo -e "\e[33mFile or directory does not exist: $ENTRY\e[0m" | tee -a "$LOG_FILE"
    fi
done < "$CONFIG_FILE"

# Notify user of completion
echo -e "\e[32m$success_count files copied successfully.\e[0m"
echo -e "\e[31m$failure_count files failed to copy.\e[0m"
echo -e "\e[33mLog of failures saved at: $LOG_FILE\e[0m"

# Commit changes
cd "$GIT_BACKUP_DIR" || exit
git add .
git commit -m "UpDotGit Backup Saved on: $(date +"%Y-%m-%d %H:%M:%S")"
echo -e "\e[32mChanges committed to Git.\e[0m"

# Notify user
echo -e "\e[32mBackup completed. Files are in $GIT_BACKUP_DIR.\e[0m"
