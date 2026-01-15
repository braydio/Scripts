#!/usr/bin/env python3
"""
Unified Arch Linux update service with OpenAI log summarization.

Features:
- System updates: pacman, yay, paru, apt-get
- Optional: flatpak updates, language/dev managers, docker image pulls
- Docker: pull images, rebuild locally if not in registry
- Cleanup + deep-clean (caches, docker, journal)
- Log capturing with OpenAI summary
"""

import argparse
import datetime as _dt
import json
import os
import subprocess
import sys
import textwrap
from pathlib import Path
import urllib.request

# --------------------------------------------------------------------------
# ANSI colors
# --------------------------------------------------------------------------

class C:
    RESET = "\033[0m"
    B = "\033[1m"
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
        self.log(f"\n{'=' * 20} {title} {'=' * 20}")

    def confirm(self, question: str) -> bool:
        if self.assume_yes:
            self.log(style(f"[auto-yes] {question}", C.GREY))
            return True
        try:
            r = input(question + " [y/N]: ").strip().lower()
        except EOFError:
            return False
        return r in ("y", "yes")

    def run(self, cmd, sudo=False, allow_fail=False) -> int:
        if sudo:
            cmd = ["sudo"] + cmd
        cmd_s = " ".join(cmd)

        if self.dry_run:
            self.log(style(f"[DRY-RUN] {cmd_s}", C.GREY))
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
                for line in proc.stdout:
                    print(line, end="")
                    log_f.write(line)
                rc = proc.wait()

            if rc != 0 and not allow_fail:
                raise subprocess.CalledProcessError(rc, cmd)
            return rc
        except Exception as e:
            self.log(style(f"Command failed: {e}", C.RED))
            if allow_fail:
                return 1
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
        ctx.log(style(f"[docker] Using existing local image", C.GREY))
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
    )

    images = sorted(set(proc.stdout.split()))
    for img in images:
        try_pull_or_build(ctx, img)


# --------------------------------------------------------------------------
# OpenAI summarization
# --------------------------------------------------------------------------

def tail_bytes(path: Path, n: int = 20000) -> str:
    with path.open("rb") as f:
        f.seek(0, 2)
        size = f.tell()
        f.seek(max(size - n, 0))
        return f.read().decode("utf-8", errors="ignore")


def build_summary_prompt(log_text: str) -> str:
    return textwrap.dedent(f"""
    Analyze the following system update log and produce a structured report.

    OUTPUT FORMAT (STRICT):
    SUMMARY_OVERVIEW:
    KEY_CHANGES:
    WARNINGS_ERRORS:
    FOLLOW_UP_ACTIONS:
    NOTABLE_DETAIL:

    BEGIN LOG
    {log_text}
    END LOG
    """)


def summarize_with_openai(ctx: Ctx):
    ctx.banner("AI Summary (OpenAI)")

    api_key = os.environ.get("OPENAI_API_KEY")
    if not api_key:
        ctx.log(style("OPENAI_API_KEY not set", C.RED))
        return

    prompt = build_summary_prompt(tail_bytes(ctx.log_file))

    payload = {
        "model": os.environ.get("OPENAI_MODEL", "gpt-4o-mini"),
        "messages": [{"role": "user", "content": prompt}],
        "temperature": 0.2,
    }

    req = urllib.request.Request(
        "https://api.openai.com/v1/chat/completions",
        data=json.dumps(payload).encode(),
        headers={
            "Content-Type": "application/json",
            "Authorization": f"Bearer {api_key}",
        },
    )

    with urllib.request.urlopen(req, timeout=30) as resp:
        parsed = json.loads(resp.read())

    summary = parsed["choices"][0]["message"]["content"].strip()
    ctx.summary_file.write_text(summary)

    ctx.log(style("\n=== AI SUMMARY (FULL) ===", C.B, C.CYAN))
    ctx.log(summary)
    ctx.log(style("=== END SUMMARY ===", C.B, C.CYAN))


# --------------------------------------------------------------------------
# Main
# --------------------------------------------------------------------------

def parse_args():
    p = argparse.ArgumentParser()
    p.add_argument("--containers", action="store_true")
    p.add_argument("--dry-run", action="store_true")
    p.add_argument("-y", "--yes", action="store_true")
    return p.parse_args()


def main():
    args = parse_args()

    log_dir = Path(os.environ.get("UPDATE_LOG_DIR", "~/Logs")).expanduser()
    log_dir.mkdir(exist_ok=True)

    ts = _dt.datetime.now().strftime("%Y%m%d-%H%M%S")
    log_file = log_dir / f"update-{ts}.log"
    summary_file = log_dir / f"update-{ts}.summary.txt"

    ctx = Ctx(
        log_file=log_file,
        summary_file=summary_file,
        dry_run=args.dry_run,
        assume_yes=args.yes,
        clean_after=True,
        deep_clean=False,
        remove_orphans=False,
        aggressive_cache=False,
        run_npm_sudo=False,
    )

    ctx.log(style("=== Unified Update Tool ===", C.B, C.BLUE))

    if args.containers:
        update_containers(ctx)

    summarize_with_openai(ctx)
    ctx.log(style(f"Log: {log_file}", C.GREEN))


if __name__ == "__main__":
    raise SystemExit(main())

