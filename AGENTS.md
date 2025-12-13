# Repository Guidelines

## Project Structure & Module Organization
- Scripts are grouped by domain: `utility/`, `file-mgmt/`, `package-mgmt/`, `device-mgmt/`, `terminal-mgmt/`, `media/`, `waybar/`, `project-mgmt/`, `shell-mgmt/`, and `Codex/`.
- Python helpers live alongside shell scripts (e.g., `utility/gpt_api.py`, `media/autofiller.py`). A local environment may be available at `.venv/`.
- Documentation lives in `docs/`. Personal helper scripts live in `self/`. Root scripts like `tab-presser.sh` are entry points.

## Build, Test, and Development Commands
- Run shell scripts: `./path/to/script.sh` (ensure executable with `chmod +x file.sh`).
- Activate Python env (if present): `source .venv/bin/activate`; run a script: `python utility/gpt_api.py`.
- Lint shell: `shellcheck **/*.sh` (static checks). Format shell: `shfmt -w .`.
- Lint/format Python (optional if installed): `ruff .` and `black .`.
- Quick safety check: `bash -n path/file.sh` and `set -x` for local tracing.

## Coding Style & Naming Conventions
- Shell: `#!/usr/bin/env bash` shebang, `set -euo pipefail`, and prefer POSIX-safe patterns. File names use kebab-case (e.g., `fast-cat.sh`).
- Python: 4-space indent, snake_case for files and functions, type hints where useful.
- Keep scripts idempotent, parameterize with flags/env vars, and include a `--help` usage block.

## Testing Guidelines
- No formal suite yet. Add smoke tests or `--dry-run` to new scripts.
- For shell, run `shellcheck` and include sample invocations in comments. For Python, factor logic into functions to enable `pytest` later (place future tests in `tests/`).
- Add non-destructive examples in the script header (e.g., `# Example: ./file-mgmt/rsync_mc.sh --dry-run`).

## Commit & Pull Request Guidelines
- Prefer Conventional Commits: `feat(utility): add financial news rss script`, `fix(file-mgmt): correct rsync path`.
- PRs should include: purpose and scope, affected scripts/paths, usage examples, risks/rollbacks, and screenshots for UI-facing changes (e.g., Waybar).
- Link related issues or notes from `ToDo.md`.

## Security & Configuration Tips
- Do not commit secrets. Use `.env` files and mirror `auto-tooling/.env.example` for new tools.
- Default to non-destructive behavior; require explicit flags for deletes/writes. Prompt before irreversible actions.

## Agent-Specific Instructions
- Make minimal, surgical changes; do not rename files or move directories without need.
- Prefer adding flags over changing defaults. Validate with `shellcheck/shfmt` or a dry-run before handing off.
