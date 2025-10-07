#!/bin/bash

# Requires: pacman, awk, grep, sed, sort, date

get_installdate() {
  pacman -Qi "$1" | awk -F': ' '/Install Date/ {print $2}'
}

get_installed_packages() {
  pacman -Qe | awk '{print $1}' | while read -r pkg; do
    date=$(get_installdate "$pkg")
    printf "%s|%s\n" "$date" "$pkg"
  done | sort
}

BATCH_SIZE=10
MARKED=()

list=()
while IFS='|' read -r date pkg; do
  list+=("$pkg")
done < <(get_installed_packages)

total=${#list[@]}
offset=0

while ((offset < total)); do
  echo
  echo "=== Package Review: $(($offset + 1)) to $(($offset + BATCH_SIZE < total ? offset + BATCH_SIZE : total)) of $total ==="
  batch=("${list[@]:offset:BATCH_SIZE}")

  for i in "${!batch[@]}"; do
    num=$((i + 1))
    marked=""
    [[ " ${MARKED[*]} " =~ " ${batch[i]} " ]] && marked="(marked)"
    printf "%2d. %s %s\n" "$num" "${batch[i]}" "$marked"
  done

  echo "Commands:"
  echo "  1-10  : Remove that package (e.g., 3)"
  echo "  i1-i10: Show info for package (e.g., i4)"
  echo "  m1-m10: Mark package for later review (e.g., m7)"
  echo "  n     : Next batch"
  echo "  q     : Quit"
  echo "  m     : Show marked list"
  read -rp "Enter command: " cmd

  case "$cmd" in
  [1-9] | 10)
    idx=$((cmd - 1))
    pkg=${batch[$idx]}
    echo "Remove $pkg? (y/N): "
    read yn
    if [[ $yn =~ ^[Yy]$ ]]; then
      sudo pacman -Rns "$pkg"
    else
      echo "Skipped."
    fi
    ;;
  i[1-9] | i10)
    idx=$((${cmd:1} - 1))
    pkg=${batch[$idx]}
    pacman -Qi "$pkg" | less
    ;;
  m[1-9] | m10)
    idx=$((${cmd:1} - 1))
    pkg=${batch[$idx]}
    MARKED+=("$pkg")
    echo "$pkg marked for later review."
    ;;
  n)
    offset=$((offset + BATCH_SIZE))
    ;;
  m)
    echo "Marked for later review:"
    for mpkg in "${MARKED[@]}"; do echo "  $mpkg"; done
    ;;
  q)
    echo "Exiting."
    break
    ;;
  *)
    echo "Invalid command."
    ;;
  esac
done
