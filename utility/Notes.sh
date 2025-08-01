#!/bin/bash
# Notes Management Script

# Function to create a new note
newnote() {
    if [ -z "$1" ]; then
        echo "Usage: newnote <note_name> [notebook_directory]"
        return 1
    fi

    note_name="$1"
    if [ -n "$2" ]; then
        notebook_dir=~/Notes/"$2"
        mkdir -p "$notebook_dir" || {
            echo "Failed to create notebook directory: $notebook_dir"
            return 1
        }

        note_file="$notebook_dir/$note_name.txt"
        if [ -e "$note_file" ]; then
            echo "Note '$note_name.txt' already exists in '$notebook_dir'."
        else
            nvim "$note_file"
        fi
    else
        note_file=~/Notes/"$note_name.txt"
        if [ -e "$note_file" ]; then
            echo "Note '$note_name.txt' already exists in '~/Notes'."
        else
            nvim "$note_file"
        fi
    fi
}

# Print, edit, delete existing notes
mynote() {
    local docs_dir=~/Notes

    local COLOR_NOTEBOOK="\033[1;34m"  # Blue for notebooks
    local COLOR_NOTE="\033[0;32m"      # Green for notes
    local COLOR_HEADER="\033[1;33m"    # Yellow for headers
    local RESET="\033[0m"              # Reset to default color

    # Check mode (print, edit, or delete)
    local mode="print"
    if [ "$1" == "edit" ]; then
        mode="edit"
        shift
    elif [ "$1" == "delete" ]; then
        mode="delete"
        shift
    fi

    if [ -z "$1" ]; then
        echo -e "${COLOR_HEADER}Indexed Notebooks in $docs_dir:${RESET}"
        find "$docs_dir" -mindepth 1 -maxdepth 1 -type d \( ! -name ".*" \) | sort | nl | while read -r index notebook; do
            notebook_name=$(basename "$notebook")
            echo -e "  ${COLOR_NOTEBOOK}${index}. ${notebook_name}${RESET}"
        done
        return
    fi

    if [[ "$1" =~ ^[0-9]+$ ]] && [ -z "$2" ]; then
        local notebook=$(find "$docs_dir" -mindepth 1 -maxdepth 1 -type d \( ! -name ".*" \) | sort | sed -n "${1}p")
        if [ -n "$notebook" ]; then
            echo -e "${COLOR_HEADER}Notes in $(basename "$notebook"):${RESET}"
            find "$notebook" -mindepth 1 -maxdepth 1 -type f \( ! -name ".*" \) | sort | nl | while read -r index note; do
                note_name=$(basename "$note" .txt)
                echo -e "  ${COLOR_NOTE}${index}. ${note_name}${RESET}"
            done

            if [ "$mode" == "delete" ]; then
                read -p "Are you sure you want to delete the entire notebook '$(basename "$notebook")'? [y/N] " confirm
                if [[ "$confirm" == [yY] ]]; then
                    rm -rf "$notebook"
                    echo -e "${COLOR_HEADER}Notebook deleted: ${COLOR_NOTE}$(basename "$notebook")${RESET}"
                else
                    echo "Aborted."
                fi
            fi
        else
            echo -e "${COLOR_HEADER}Notebook with index '${1}' does not exist.${RESET}"
        fi
        return
    fi

    if [[ "$1" =~ ^[0-9]+$ ]] && [[ "$2" =~ ^[0-9]+$ ]]; then
        local notebook=$(find "$docs_dir" -mindepth 1 -maxdepth 1 -type d \( ! -name ".*" \) | sort | sed -n "${1}p")
        local note=$(find "$notebook" -type f \( ! -name ".*" \) | sort | sed -n "${2}p")
        if [ -n "$note" ]; then
            if [ "$mode" == "edit" ]; then
                echo -e "${COLOR_HEADER}Opening ${COLOR_NOTE}$(basename "$note")${RESET} in nvim..."
                nvim "$note"
            elif [ "$mode" == "delete" ]; then
                read -p "Are you sure you want to delete the note '$(basename "$note")'? [y/N] " confirm
                if [[ "$confirm" == [yY] ]]; then
                    rm "$note"
                    echo -e "${COLOR_HEADER}Note deleted: ${COLOR_NOTE}$(basename "$note")${RESET}"
                else
                    echo "Aborted."
                fi
            else
                echo -e "${COLOR_HEADER}Contents of ${COLOR_NOTE}$(basename "$note")${RESET}:"
                cat "$note"
            fi
        else
            echo -e "${COLOR_HEADER}Note with index '${2}' does not exist in notebook '${1}'.${RESET}"
        fi
        return
    fi

    echo -e "${COLOR_HEADER}Usage:${RESET}"
    echo -e "  ${COLOR_NOTEBOOK}mynote${RESET}                  - List all notebooks"
    echo -e "  ${COLOR_NOTEBOOK}mynote <notebook_index>${RESET} - List all notes in a notebook"
    echo -e "  ${COLOR_NOTEBOOK}mynote <notebook_index> <note_index>${RESET} - Print the contents of a note"
    echo -e "  ${COLOR_NOTEBOOK}mynote edit <notebook_index> <note_index>${RESET} - Open a note for editing in nvim"
    echo -e "  ${COLOR_NOTEBOOK}mynote delete <notebook_index>${RESET} - Delete an entire notebook"
    echo -e "  ${COLOR_NOTEBOOK}mynote delete <notebook_index> <note_index>${RESET} - Delete a specific note"
}

# Dispatcher for subcommands
case "$1" in
    newnote)
        shift
        newnote "$@"
        ;;
    mynote)
        shift
        mynote "$@"
        ;;
    *)
        echo "Usage: $0 {newnote|mynote} [args...]"
        ;;
esac

