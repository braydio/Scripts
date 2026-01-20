#!/usr/bin/env python3
"""
Unified Arch Linux update service with OpenAI log summarization.

Features:
- System updates: pacman
- Optional: AUR helpers (yay/paru), flatpak, npm, docker image pulls
- Cleanup + deep-clean (caches, docker, journal)
- Log capturing with OpenAI summary
"""

import argparse
import datetime as _dt
import json
import os
import shutil
import subprocess
import sys
import textwrap
import urllib.request
from pathlib import Path


# --------------------------------------------------------------------------
# ANSI colors / style
# --------------------------------------------------------------------------

class C:
    RESET = "\033[0m"
    B = "\033[1m"
    DIM = "\033[2m"
    RED = "\033[31m"
    GREEN = "\033[32m"
    YEL = "\033[33m"
    BLUE = "\033[34m"
    CYAN = "\033[36m"
    GREY = "\033[90m"


def style(text, *colors):
    return "".join(colors) + str(text) + C.RESET


# --------------------------------------------------------------------------
# Context
# --------------------------------------------------------------------------

class Ctx:
    def __init__(
        self,
        log_file: Path,
        summary_file: Path,
        dry_run: bool,
        assume_yes: bool,
        clean_after: bool,
        deep_clean: bool,
        remove_orphans: bool,
        aggressive_cache: bool,
        run_npm_sudo: bool,
    ):
        self.log_file = log_file
        self.summary_file = summary_file
        self.dry_run = dry_run
        self.assume_yes = assume_yes
        self.clean_after = clean_after
        self.deep_clean = deep_clean
        self.remove_orphans = remove_orphans
        self.aggressive_cache = aggressive_cache
        self.run_npm_sudo = run_npm_sudo

    def log(self, msg: str):
        msg = msg.rstrip("\n")
        print(msg)
        try:
            with self.log_file.open("a", encoding="utf-8") as f:
                f.write(msg + "\n")
        except Exception:
            pass

    def banner(self, title: str):
        bar = "=" * 20
        self.log(f"\n{bar} {title} {bar}")

    def confirm(self, question: str) -> bool:
        if self.assume_yes:
            self.log(style(f"[auto-yes] {question}", C.GREY))
            return True
        try:
            r = input(question + " [y/N]: ").strip().lower()
        except EOFError:
            return False
        return r in ("y", "yes")

    def run(self, cmd, sudo: bool = False, allow_fail: bool = False) -> int:
        if sudo:
            cmd = ["sudo"] + cmd
        cmd_s = " ".join(cmd)

        if self.dry_run:
            self.log(style(f"[DRY-RUN] + {cmd_s}", C.GREY))
            return 0

        self.log(style(f"+ {cmd_s}", C.GREY))
        try:
            with self.log_file.open("a", encoding="utf-8") as log_f:
                proc = subprocess.Popen(
                    cmd,
                    stdout=subprocess.PIPE,
                    stderr=subprocess.STDOUT,
                    text=True,
                    bufsize=1,
                )
                assert proc.stdout is not None
                for line in proc.stdout:
                    sys.stdout.write(line)
                    sys.stdout.flush()
                    try:
                        log_f.write(line)
                        log_f.flush()
                    except Exception:
                        pass
                rc = proc.wait()

            if rc != 0:
                self.log(style(f"Command failed {rc}: {cmd_s}", C.RED))
                if allow_fail:
                    return rc
                raise subprocess.CalledProcessError(rc, cmd)
            return rc
        except FileNotFoundError:
            self.log(style(f"Command not found: {cmd[0]}", C.RED))
            if allow_fail:
                return 127
            raise


# --------------------------------------------------------------------------
# Helpers
# --------------------------------------------------------------------------

def have(cmd: str) -> bool:
    return subprocess.call(
        ["which", cmd],
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
    ) == 0


def docker_image_exists_locally(image: str) -> bool:
    return subprocess.call(
        ["docker", "image", "inspect", image],
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
    ) == 0


def try_pull_or_build(ctx: Ctx, image: str):
    ctx.log(style(f"[docker] {image}", C.GREY))

    if ctx.run(["docker", "pull", image], allow_fail=True) == 0:
        ctx.log(style(f"[docker] Pulled {image}", C.GREEN))
        return

    if docker_image_exists_locally(image):
        ctx.log(style("[docker] Using existing local image", C.GREY))
        return

    cwd = Path.cwd()
    if (cwd / "Dockerfile").exists():
        ctx.log(style("[docker] Rebuilding from Dockerfile", C.CYAN))
        ctx.run(["docker", "build", "-t", image, "."], allow_fail=True)
        return

    if (cwd / "docker-compose.yml").exists():
        ctx.log(style("[docker] Rebuilding via docker compose", C.CYAN))
        ctx.run(["docker", "compose", "build"], allow_fail=True)
        return

    ctx.log(style("[docker] No build context found", C.RED))


# --------------------------------------------------------------------------
# Update sections
# --------------------------------------------------------------------------

def update_system_pacman(ctx: Ctx):
    ctx.banner("System (pacman)")

    if not have("pacman"):
        ctx.log("pacman not installed")
        return

    ctx.run(["pacman", "-Syu", "--noconfirm"], sudo=True)


def update_aur(ctx: Ctx):
    ctx.banner("AUR helpers")

    ran = False
    for tool in ("yay", "paru"):
        if have(tool):
            ran = True
            ctx.run([tool, "-Syu", "--noconfirm"], allow_fail=True)

    if not ran:
        ctx.log("No AUR helper found (yay/paru)")


def update_flatpak(ctx: Ctx):
    ctx.banner("Flatpak")

    if not have("flatpak"):
        ctx.log("flatpak not installed")
        return

    ctx.run(["flatpak", "update", "-y"], allow_fail=True)


def update_npm(ctx: Ctx):
    ctx.banner("npm")

    if not have("npm"):
        ctx.log("npm not installed")
        return

    ctx.run(["npm", "-g", "update"], sudo=ctx.run_npm_sudo, allow_fail=True)


def update_containers(ctx: Ctx):
    ctx.banner("Containers")

    if not have("docker"):
        ctx.log("docker not installed")
        return

    if not ctx.confirm("Pull or rebuild images for running containers?"):
        return

    proc = subprocess.run(
        ["docker", "ps", "--format", "{{.Image}}"],
        stdout=subprocess.PIPE,
        text=True,
        check=False,
    )

    images = sorted(set(proc.stdout.split()))
    for img in images:
        try_pull_or_build(ctx, img)


# --------------------------------------------------------------------------
# Cleanup sections
# --------------------------------------------------------------------------

def cleanup_standard(ctx: Ctx):
    ctx.banner("Cleanup")

    if have("pacman"):
        ctx.run(["pacman", "-Sc", "--noconfirm"], sudo=True, allow_fail=True)

    if have("paccache"):
        ctx.run(["paccache", "-r"], sudo=True, allow_fail=True)

    if have("yay"):
        ctx.run(["yay", "-Sc", "--noconfirm"], allow_fail=True)

    if have("paru"):
        ctx.run(["paru", "-Sc", "--noconfirm"], allow_fail=True)


def remove_orphans(ctx: Ctx):
    if not have("pacman"):
        ctx.log("pacman not installed")
        return

    ctx.banner("Orphan packages")

    proc = subprocess.run(
        ["pacman", "-Qtdq"],
        stdout=subprocess.PIPE,
        stderr=subprocess.DEVNULL,
        text=True,
        check=False,
    )
    orphans = [p for p in proc.stdout.split() if p.strip()]

    if not orphans:
        ctx.log("No orphaned packages found")
        return

    cmd = ["pacman", "-Rns", "--noconfirm"] + orphans
    if ctx.dry_run:
        ctx.log(style(f"[DRY-RUN] + sudo {' '.join(cmd)}", C.GREY))
        return

    ctx.run(cmd, sudo=True, allow_fail=True)


def aggressive_cache_cleanup(ctx: Ctx):
    ctx.banner("Aggressive cache cleanup")

    cache_dir = Path.home() / ".cache"
    if not cache_dir.exists():
        ctx.log("~/.cache not found")
        return

    excludes = {"google-chrome", "chromium", "mozilla", "vivaldi", "brave"}
    for entry in cache_dir.iterdir():
        if entry.name in excludes:
            ctx.log(style(f"Skipping cache: {entry.name}", C.GREY))
            continue

        if ctx.dry_run:
            ctx.log(style(f"[DRY-RUN] Would remove {entry}", C.GREY))
            continue

        try:
            if entry.is_dir() and not entry.is_symlink():
                shutil.rmtree(entry)
            else:
                entry.unlink()
            ctx.log(style(f"Removed {entry}", C.GREEN))
        except Exception as e:
            ctx.log(style(f"Failed to remove {entry}: {e}", C.RED))


def deep_cleanup(ctx: Ctx):
    ctx.banner("Deep clean")

    if have("docker"):
        ctx.run(["docker", "system", "prune", "-af"], allow_fail=True)

    if have("journalctl"):
        ctx.run(["journalctl", "--vacuum-time=7d"], sudo=True, allow_fail=True)


# --------------------------------------------------------------------------
# Summarization helpers
# --------------------------------------------------------------------------

def tail_bytes(path: Path, n: int = 20000) -> str:
    try:
        with path.open("rb") as f:
            f.seek(0, 2)
            size = f.tell()
            f.seek(0 if size <= n else -n, 2)
            return f.read().decode("utf-8", errors="ignore")
    except Exception:
        return ""


def build_summary_prompt(log_text: str) -> str | None:
    if not log_text.strip():
        return None

    return textwrap.dedent(f"""
    Analyze the following system update log and produce a structured report.

    OUTPUT FORMAT (STRICT):
    SUMMARY_OVERVIEW:
    2–3 factual sentences.

    KEY_CHANGES:
    - Bullet list grouped by manager.

    WARNINGS_ERRORS:
    - Bullet list or "None".

    FOLLOW_UP_ACTIONS:
    - Bullet list or "None".

    NOTABLE_DETAIL:
    - Exactly one concrete observation.

    RULES:
    - No filler or meta commentary.
    - No extra sections.

    BEGIN LOG
    {log_text}
    END LOG
    """).strip()


def parse_summary_sections(text: str) -> dict[str, str]:
    sections = {}
    current = None
    buf = []

    for line in text.splitlines():
        line = line.rstrip()
        if not line:
            continue
        if line.endswith(":") and line[:-1].isupper():
            if current:
                sections[current] = "\n".join(buf).strip()
            current = line[:-1]
            buf = []
        else:
            buf.append(line)

    if current:
        sections[current] = "\n".join(buf).strip()

    return sections


def select_terminal_section(sections: dict[str, str]) -> tuple[str, str]:
    for key in ("WARNINGS_ERRORS", "FOLLOW_UP_ACTIONS", "NOTABLE_DETAIL", "SUMMARY_OVERVIEW"):
        body = sections.get(key)
        if body and body.lower() != "none":
            return key, body
    return "SUMMARY_OVERVIEW", sections.get("SUMMARY_OVERVIEW", "")


def summarize_with_openai(ctx: Ctx) -> bool:
    ctx.banner("LLM Summary (OpenAI)")

    if ctx.dry_run:
        ctx.log("[DRY-RUN] Would summarize log with OpenAI")
        return True

    prompt = build_summary_prompt(tail_bytes(ctx.log_file))
    if not prompt:
        ctx.log("No log content to summarize.")
        return False

    api_key = os.environ.get("OPENAI_API_KEY")
    if not api_key:
        ctx.log(style("OPENAI_API_KEY not set.", C.RED))
        return False

    model = os.environ.get("OPENAI_MODEL", "gpt-4o-mini")

    payload = {
        "model": model,
        "messages": [{"role": "user", "content": prompt}],
        "temperature": 0.2,
    }

    try:
        req = urllib.request.Request(
            "https://api.openai.com/v1/chat/completions",
            data=json.dumps(payload).encode(),
            headers={
                "Authorization": f"Bearer {api_key}",
                "Content-Type": "application/json",
            },
        )
        with urllib.request.urlopen(req, timeout=30) as resp:
            data = json.loads(resp.read().decode())
    except Exception as e:
        ctx.log(style(f"OpenAI request failed: {e}", C.RED))
        return False

    choices = data.get("choices") or []
    if not choices:
        ctx.log(style("OpenAI returned no choices.", C.RED))
        return False

    summary = choices[0]["message"]["content"].strip()
    if not summary:
        ctx.log(style("OpenAI returned empty summary.", C.RED))
        return False

    ctx.summary_file.write_text(summary, encoding="utf-8")
    ctx.log(style(f"Summary saved to: {ctx.summary_file}", C.GREEN))

    sections = parse_summary_sections(summary)
    name, body = select_terminal_section(sections)
    ctx.log(style(f"\n[{name}]", C.B, C.CYAN))
    ctx.log(body)

    return True


# --------------------------------------------------------------------------
# Argument parsing / main
# --------------------------------------------------------------------------

def parse_args():
    p = argparse.ArgumentParser(
        prog="arch-update.py",
        description=(
            "Unified Arch Linux updater.\n\n"
            "Runs system updates, optional cleanup, and can generate a structured "
            "LLM summary of the update log using the OpenAI API."
        ),
        formatter_class=argparse.RawTextHelpFormatter,
        epilog=textwrap.dedent(
            """
            BEHAVIOR NOTES:

              • By default, the script ASSUMES YES to prompts.
                Use --manual to require confirmations.

              • If --no-llm is NOT provided, the script will:
                  - Capture the update log
                  - Send the tail of the log to OpenAI
                  - Write a structured summary to a .summary.txt file
                  - Print the most relevant section to the terminal

              • If --dry-run is set:
                  - Commands are printed but NOT executed
                  - No system changes occur
                  - LLM summarization still runs (unless --no-llm is set)

              • Logs are written to ~/Logs by default, or to --log-dir if provided.

              • OPENAI_API_KEY must be set in the environment for summarization.

            EXAMPLES:

              Run full system update with auto-confirm and summary:
                arch-update.py

              Require confirmations and skip cleanup:
                arch-update.py --manual --no-clean

              Run safely to see what would happen:
                arch-update.py --dry-run

              Disable LLM summarization entirely:
                arch-update.py --no-llm

              Include AUR, flatpak, and npm updates:
                arch-update.py --aur --flatpak --npm
            """
        ),
    )

    # ------------------------------------------------------------------
    # Core behavior flags
    # ------------------------------------------------------------------
    core = p.add_argument_group("Core behavior")

    core.add_argument(
        "--dry-run",
        action="store_true",
        help="Print commands instead of executing them (no system changes).",
    )

    core.add_argument(
        "--yes", "-y",
        dest="assume_yes",
        action="store_true",
        help="Automatically answer 'yes' to all prompts (default behavior).",
    )

    core.add_argument(
        "--manual",
        action="store_true",
        help="Require confirmation prompts (disables auto-yes).",
    )

    # ------------------------------------------------------------------
    # Update options
    # ------------------------------------------------------------------
    updates = p.add_argument_group("Update options")

    updates.add_argument(
        "--no-system",
        action="store_true",
        help="Skip pacman system updates.",
    )

    updates.add_argument(
        "--aur",
        action="store_true",
        help="Run AUR helper updates (yay/paru).",
    )

    updates.add_argument(
        "--flatpak",
        action="store_true",
        help="Run flatpak updates.",
    )

    updates.add_argument(
        "--npm",
        action="store_true",
        help="Run npm global updates.",
    )

    updates.add_argument(
        "--containers",
        action="store_true",
        help="Pull/rebuild images for running containers.",
    )

    # ------------------------------------------------------------------
    # Cleanup options
    # ------------------------------------------------------------------
    clean = p.add_argument_group("Cleanup options")

    clean.add_argument(
        "--no-clean",
        action="store_true",
        help="Skip standard cleanup steps (package caches, temp files).",
    )

    clean.add_argument(
        "--deep-clean",
        action="store_true",
        help=(
            "Perform deeper cleanup:\n"
            "  - docker system prune\n"
            "  - journalctl vacuum\n"
        ),
    )

    clean.add_argument(
        "--remove-orphans",
        action="store_true",
        help="Remove orphaned Arch packages (pacman -Qtdq && pacman -Rns).",
    )

    clean.add_argument(
        "--aggressive-cache",
        action="store_true",
        help="Aggressively delete ~/.cache contents (except browser caches).",
    )

    # ------------------------------------------------------------------
    # Language / tooling quirks
    # ------------------------------------------------------------------
    tools = p.add_argument_group("Tooling quirks")

    tools.add_argument(
        "--npm-sudo",
        action="store_true",
        help="Run 'npm -g update' using sudo instead of user context.",
    )

    # ------------------------------------------------------------------
    # Logging & summarization
    # ------------------------------------------------------------------
    log = p.add_argument_group("Logging & summarization")

    log.add_argument(
        "--no-llm",
        action="store_true",
        help="Disable OpenAI LLM log summarization.",
    )

    log.add_argument(
        "--log-dir",
        metavar="PATH",
        help="Directory to write logs and summaries (default: ~/Logs).",
    )

    args = p.parse_args()

    # Manual vs auto-yes resolution
    if args.manual:
        args.assume_yes = False
    elif not args.assume_yes:
        args.assume_yes = True

    return args


def main():
    args = parse_args()

    log_dir = Path(args.log_dir or "~/Logs").expanduser()
    log_dir.mkdir(parents=True, exist_ok=True)

    ts = _dt.datetime.now().strftime("%Y%m%d-%H%M%S")
    log_file = log_dir / f"update-{ts}.log"
    summary_file = log_dir / f"update-{ts}.summary.txt"

    ctx = Ctx(
        log_file=log_file,
        summary_file=summary_file,
        dry_run=args.dry_run,
        assume_yes=args.assume_yes,
        clean_after=not args.no_clean,
        deep_clean=args.deep_clean,
        remove_orphans=args.remove_orphans,
        aggressive_cache=args.aggressive_cache,
        run_npm_sudo=args.npm_sudo,
    )

    ctx.log(style("=== Unified Arch Update Tool ===", C.B, C.BLUE))
    ctx.log(f"Started: {_dt.datetime.now().isoformat(timespec='seconds')}")

    if not args.no_system:
        update_system_pacman(ctx)

    if args.aur:
        update_aur(ctx)

    if args.flatpak:
        update_flatpak(ctx)

    if args.npm:
        update_npm(ctx)

    if args.containers:
        update_containers(ctx)

    if ctx.clean_after:
        cleanup_standard(ctx)

    if ctx.remove_orphans:
        remove_orphans(ctx)

    if ctx.aggressive_cache:
        aggressive_cache_cleanup(ctx)

    if ctx.deep_clean:
        deep_cleanup(ctx)

    if not args.no_llm:
        summarize_with_openai(ctx)

    ctx.log(style(f"Log: {log_file}", C.GREEN))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
