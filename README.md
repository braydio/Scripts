# Scripts Collection

This repository now groups the assorted scripts by the kind of tasks they support.  The table below describes each top-level directory and highlights notable tools inside it.

| Directory | Purpose |
| --- | --- |
| `desktop/` | Desktop environment helpers for Hyprland, Kitty, terminal configuration, Waybar widgets, and keybinding utilities. |
| `integrations/` | Communication helpers for sending commands or notifications to remote services. |
| `media/` | Maintenance scripts for inspecting, cleaning, and resizing media libraries. |
| `personal/` | Lightweight personal habit trackers and logs. |
| `productivity/` | Focus, planning, and project-management helpers (including note utilities and financial feeds). |
| `system/` | System-care scripts, split into `file_management/`, `package_management/`, `shell/`, and `utilities/`. |

## Housekeeping

- Obsolete or duplicate scripts have been removed (`Codex/pnx_main.sh`, `utility/gpt_api.py`, `utility/archnotes-linux.sh`, and historical backups under `file-mgmt/backups/` and `package-mgmt/backups/`).
- File-management helpers now live in `system/file_management/`; dependent scripts reference the new paths.
- Legacy top-level folders such as `file-mgmt`, `package-mgmt`, `project-mgmt`, `shell-mgmt`, `terminal-mgmt`, and `utility` have been retired in favour of the structure above.

## Contributing

1. Place new scripts in the directory that best matches their intent.
2. Keep configuration files and documentation alongside the scripts they support.
3. Prefer descriptive file names and shebangs for executables.
