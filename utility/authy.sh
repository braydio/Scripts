authy() {
    local arg="$1"
    if [[ -z "$arg" ]]; then
        echo "Usage: authy <service>"
        return 1
    fi

    # Get JSON from your API
    local json token
    json=$(curl -s "http://192.168.1.227:6061/${arg}")

    # Extract token using jq
    token=$(printf '%s' "$json" | jq -r '.token')

    # Copy to clipboard (Linux / Arch / X11 / Wayland compatible)
    if command -v wl-copy >/dev/null 2>&1; then
        printf '%s' "$token" | wl-copy
    elif command -v xclip >/dev/null 2>&1; then
        printf '%s' "$token" | xclip -selection clipboard
    elif command -v xsel >/dev/null 2>&1; then
        printf '%s' "$token" | xsel --clipboard --input
    else
        echo "⚠️ No clipboard tool installed (install wl-clipboard or xclip)"
        return 2
    fi

    # Output nicely
    echo "🔐 Token copied to clipboard: $token"
}

