import subprocess
import os

# File paths
bashrc_path = os.path.expanduser("~/.bashrc")
hyprland_conf_path = os.path.expanduser("~/.config/hypr/hyprland.conf")

# Extract keybinds from .bashrc and hyprland.conf
def extract_keybinds(file_path, search_terms):
    keybinds = []
    if not os.path.exists(file_path):
        print(f"Warning: {file_path} does not exist.")
        return keybinds

    with open(file_path, "r") as file:
        for line in file:
            if any(term in line for term in search_terms):
                keybinds.append(f"{os.path.basename(file_path)}: {line.strip()}")
    return keybinds

# Fuzzy search using fzf
def fuzzy_search():
    search_terms = ["alias", "bind", "exec", "function"]
    bashrc_binds = extract_keybinds(bashrc_path, search_terms)
    hyprland_binds = extract_keybinds(hyprland_conf_path, ["bind", "exec"])

    all_binds = bashrc_binds + hyprland_binds
    if not all_binds:
        print("No keybindings found.")
        return

    try:
        # Launch `fzf` and pass keybindings as input
        process = subprocess.Popen(['fzf'], stdin=subprocess.PIPE, text=True)
        process.communicate(input="\n".join(all_binds))
    except FileNotFoundError:
        print("Error: `fzf` not found. Install it using `sudo pacman -S fzf`.")

if __name__ == "__main__":
    fuzzy_search()


