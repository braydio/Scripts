
#!/bin/bash

# Default backup directory
BACKUP_DIR="${PWD}/backups"
mkdir -p "$BACKUP_DIR"

# Function to create a backup
backup_file() {
    # Determine the file to back up
    if [ $# -eq 0 ]; then
        # Find all files in the current directory
        FILES=($(find . -maxdepth 1 -type f))
        FILE_COUNT=${#FILES[@]}

        if [ $FILE_COUNT -eq 0 ]; then
            echo "Error: No files found in the current directory to back up."
            exit 1
        elif [ $FILE_COUNT -eq 1 ]; then
            FILE="${FILES[0]}"
        else
            # Use fuzzy finder for multiple files
            echo "Select a file to back up:"
            if command -v fzf &>/dev/null; then
                FILE=$(printf "%s\n" "${FILES[@]}" | fzf)
            else
                echo "Error: Multiple files found. Install 'fzf' for easy selection."
                exit 1
            fi
        fi
    elif [ $# -eq 1 ]; then
        FILE=$1
    else
        echo "Usage: quickbackup [file]"
        exit 1
    fi

    # Ensure the file exists
    if [ ! -f "$FILE" ]; then
        echo "Error: File '$FILE' does not exist."
        exit 1
    fi

    # Simplified filenames for backups
    FILENAME=$(basename "$FILE")
    BACKUP_PREFIX="${BACKUP_DIR}/${FILENAME}"
    BACKUPS=("$BACKUP_PREFIX".*)

    # Remove the oldest backup if more than 2 exist
    if [ ${#BACKUPS[@]} -gt 1 ]; then
        OLDEST_BACKUP=$(ls -t "${BACKUPS[@]}" 2>/dev/null | tail -n 1)
        rm -f "$OLDEST_BACKUP"
    fi

    # Determine the next available version
    NEXT_VERSION=$(($(ls "${BACKUP_PREFIX}".* 2>/dev/null | wc -l) + 1))

    # Save the backup
    BACKUP_FILE="${BACKUP_PREFIX}.${NEXT_VERSION}"
    cp "$FILE" "$BACKUP_FILE"
    echo "Backup for '$FILE' created as '$BACKUP_FILE'."
}

# Function to restore a backup
restore_backup() {
    if [ ! -d "$BACKUP_DIR" ]; then
        echo "Error: Backup directory $BACKUP_DIR does not exist."
        exit 1
    fi

    BACKUPS=("$BACKUP_DIR"/*)

    if [ ${#BACKUPS[@]} -eq 0 ]; then
        echo "Error: No backup files found in $BACKUP_DIR."
        exit 1
    elif [ ${#BACKUPS[@]} -eq 1 ]; then
        SELECTED_BACKUP="${BACKUPS[0]}"
    else
        echo "Select a backup to restore:"
        if command -v fzf &>/dev/null; then
            SELECTED_BACKUP=$(printf "%s\n" "${BACKUPS[@]}" | fzf)
        else
            echo "Error: Multiple backups found. Install 'fzf' for easy selection."
            exit 1
        fi
    fi

    if [ -n "$SELECTED_BACKUP" ]; then
        RESTORED_FILE=$(basename "${SELECTED_BACKUP}" | sed 's/\.[0-9]*$//')
        cp "$SELECTED_BACKUP" "$RESTORED_FILE"
        echo "Backup restored as '$RESTORED_FILE'."
    else
        echo "No backup selected. Restore operation canceled."
        exit 1
    fi
}

# Main script logic
case "$1" in
    -r)
        restore_backup
        ;;
    *)
        backup_file "$@"
        ;;
esac
