authy() {
  curl -s http://192.168.1.78:6061/openai | jq -r '.code, .expires_in' |
    while read -r code && read -r expires; do
      printf "%s" "$code" | wl-copy
      echo "$expires"
    done
}
