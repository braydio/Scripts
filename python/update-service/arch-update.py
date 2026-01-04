#!/usr/bin/env python3
"""
Unified Arch/DietPi system updater with Codex CLI log summarization.

Features:
- System updates: pacman, yay, paru, apt-get
- Optional: flatpak updates, language/dev managers, docker image pulls
- Cleanup + deep-clean (caches, docker, journal)
- Log capturing with Codex CLI summary (codex exec --json)
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
        llm_backend: str,
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
        self.llm_backend = llm_backend

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
            # Tee subprocess output to both terminal and the log file.
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


def in_git_repo(path: Path) -> bool:
    """Return True if the cwd is inside a Git worktree."""
    try:
        proc = subprocess.run(
            ["git", "rev-parse", "--is-inside-work-tree"],
            cwd=path,
            stdout=subprocess.PIPE,
            stderr=subprocess.DEVNULL,
            text=True,
            check=True,
        )
        return proc.stdout.strip() == "true"
    except Exception:
        return False


def clear_log_dir(log_dir: Path, assume_yes: bool, dry_run: bool) -> None:
    if not log_dir.exists():
        return
    entries = list(log_dir.iterdir())
    if not entries:
        print(style("Log directory already empty.", C.GREY))
        return
    if not assume_yes:
        try:
            r = input(f"Clear log files in {log_dir}? [y/N]: ").strip().lower()
        except EOFError:
            return
        if r not in ("y", "yes"):
            print(style("Log clear canceled.", C.GREY))
            return

    for child in entries:
        if child.is_dir():
            print(style(f"Skipping directory in log dir: {child}", C.YEL))
            continue
        if dry_run:
            print(style(f"[DRY-RUN] Would remove {child}", C.GREY))
            continue
        try:
            child.unlink()
            print(style(f"Removed {child}", C.GREY))
        except Exception as e:
            print(style(f"Failed to remove {child}: {e}", C.RED))


# --------------------------------------------------------------------------
# Update managers
# --------------------------------------------------------------------------

_HELP_CACHE: dict[str, str] = {}


def _help_text(cmd: str) -> str:
    """Best-effort `cmd --help` output for feature detection."""
    if cmd in _HELP_CACHE:
        return _HELP_CACHE[cmd]
    try:
        proc = subprocess.run(
            [cmd, "--help"],
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT,
            text=True,
            check=False,
        )
        out = proc.stdout or ""
    except Exception:
        out = ""
    _HELP_CACHE[cmd] = out
    return out


def _maybe_add_flag(args: list[str], cmd: str, flag: str, value: str | None = None) -> None:
    ht = _help_text(cmd)
    if not ht or flag not in ht:
        return
    args.append(flag)
    if value is not None:
        args.append(value)


def update_system(ctx: Ctx):
    ctx.banner("System packages")

    # DietPi / Debian family
    if have("apt-get"):
        if ctx.confirm("Run apt-get update && apt-get upgrade?"):
            ctx.run(["apt-get", "update"], sudo=True)
            ctx.run(["apt-get", "upgrade", "-y"], sudo=True)
            ctx.run(["apt-get", "autoremove", "-y"], sudo=True, allow_fail=True)
            ctx.run(["apt-get", "autoclean", "-y"], sudo=True, allow_fail=True)
        else:
            ctx.log("Skipped apt-get")

    # Arch pacman
    if have("pacman"):
        args = ["pacman", "-Syu"]
        if ctx.assume_yes:
            args.append("--noconfirm")
        if ctx.confirm("Run pacman -Syu?"):
            ctx.run(args, sudo=True)
        else:
            ctx.log("Skipped pacman")

    # yay
    aur_helper = None
    for helper in ("yay", "paru"):
        if have(helper):
            aur_helper = helper
            break

    if aur_helper:
        args = [aur_helper, "-Syu", "--needed"]
        if ctx.assume_yes:
            args.append("--noconfirm")
            # Reduce "menu" prompts that can break unattended runs.
            _maybe_add_flag(args, aur_helper, "--answerdiff", "None")
            _maybe_add_flag(args, aur_helper, "--answerclean", "None")
            _maybe_add_flag(args, aur_helper, "--sudoloop")

        if ctx.confirm(f"Run {aur_helper} -Syu?"):
            # AUR helpers can fail for transient reasons; don't abort the whole run.
            ctx.run(args, allow_fail=True)
        else:
            ctx.log(f"Skipped {aur_helper}")


def update_flatpak(ctx: Ctx):
    ctx.banner("Flatpak")
    if not have("flatpak"):
        ctx.log("flatpak not installed")
        return
    if ctx.confirm("Run flatpak update?"):
        args = ["flatpak", "update"]
        if ctx.assume_yes:
            args.append("-y")
        ctx.run(args, allow_fail=True)
    else:
        ctx.log("Skipped flatpak")


def update_languages(ctx: Ctx):
    ctx.banner("Language & dev package managers")

    # pipx
    if have("pipx") and ctx.confirm("pipx upgrade --all?"):
        ctx.run(["pipx", "upgrade", "--all"], allow_fail=True)
    elif have("pipx"):
        ctx.log("Skipped pipx")

    # pip user
    if ctx.confirm("Upgrade user pip packages?"):
        python_bin = sys.executable
        snippet = textwrap.dedent("""
            import subprocess, sys, json

            exe = sys.executable
            try:
                out = subprocess.check_output(
                    [exe, "-m", "pip", "list", "--user", "--outdated", "--format", "json"],
                    text=True,
                )
            except Exception:
                sys.exit(0)

            try:
                items = json.loads(out)
            except Exception:
                items = []

            for pkg in items:
                name = pkg["name"]
                print(f"[pip] upgrading {name}...")
                try:
                    subprocess.check_call([exe, "-m", "pip", "install", "--user", "--upgrade", name])
                except subprocess.CalledProcessError:
                    print(f"[pip] failed to upgrade {name}")
        """)
        if ctx.dry_run:
            ctx.log(style("[DRY-RUN] Would upgrade pip packages", C.GREY))
        else:
            ctx.log("[pip] checking user packages...")
            ctx.run([python_bin, "-c", snippet], allow_fail=True)
    else:
        ctx.log("Skipped pip user")

    # npm global
    if have("npm") and ctx.confirm("npm -g update?"):
        ctx.run(["npm", "-g", "update"], sudo=ctx.run_npm_sudo, allow_fail=True)
    elif have("npm"):
        ctx.log("Skipped npm")

    # cargo
    if have("cargo-install-update") and ctx.confirm("cargo install-update -a?"):
        ctx.run(["cargo", "install-update", "-a"], allow_fail=True)
    elif have("cargo"):
        ctx.log("Skipped cargo or cargo-install-update missing")

    # gem
    if have("gem") and ctx.confirm("gem update user?"):
        ctx.run(["gem", "update", "--user-install"], allow_fail=True)
    elif have("gem"):
        ctx.log("Skipped gem")


def update_containers(ctx: Ctx):
    ctx.banner("Containers")
    if not have("docker"):
        ctx.log("docker not installed")
        return
    if ctx.confirm("Pull images for running containers?"):
        ctx.run(["bash", "-c", "docker ps --format '{{.Image}}' | xargs -r -n1 docker pull"], allow_fail=True)
        ctx.log("Hint: restart containers manually if needed.")
    else:
        ctx.log("Skipped docker image pulls")


# --------------------------------------------------------------------------
# Cleanup
# --------------------------------------------------------------------------

def cleanup(ctx: Ctx):
    ctx.banner("Cleanup (caches & misc)")

    # pacman cache
    if have("pacman"):
        if have("paccache"):
            ctx.run(["paccache", "-rk0"], sudo=True, allow_fail=True)
            ctx.run(["paccache", "-ruk0"], sudo=True, allow_fail=True)
        else:
            ctx.run(["pacman", "-Scc", "--noconfirm"], sudo=True, allow_fail=True)

        # Clean any leftover .part files in /var/cache/pacman/pkg
        pkg_dir = Path("/var/cache/pacman/pkg")
        if pkg_dir.is_dir():
            for f in pkg_dir.glob("*.part"):
                if ctx.dry_run:
                    ctx.log(style(f"[DRY-RUN] Would remove {f}", C.GREY))
                else:
                    try:
                        ctx.log(style(f"Removing stray pacman partial: {f}", C.GREY))
                        f.unlink()
                    except Exception as e:
                        ctx.log(style(f"Failed to remove {f}: {e}", C.RED))

        # Optional orphan removal
        if ctx.remove_orphans:
            remove_orphans(ctx)

    # AUR caches
    for x in ["yay", "paru", "pikaur"]:
        p = Path.home() / ".cache" / x
        if p.exists():
            ctx.run(["rm", "-rf", str(p)], allow_fail=True)

    # flatpak unused
    if have("flatpak"):
        ctx.run(["flatpak", "uninstall", "--unused", "-y"], allow_fail=True)

    # npm cache
    if have("npm"):
        ctx.run(["npm", "cache", "clean", "--force"], allow_fail=True)

    # pip cache
    ctx.run([sys.executable, "-m", "pip", "cache", "purge"], allow_fail=True)
    # Extra pip cache cleanup
    pip_cache = Path.home() / ".cache" / "pip"
    for sub in ("http", "selfcheck"):
        p = pip_cache / sub
        if p.exists():
            ctx.run(["rm", "-rf", str(p)], allow_fail=True)


def cleanup_deep(ctx: Ctx):
    ctx.banner("Deep Cleanup")

    # docker prune
    if have("docker"):
        ctx.run(["docker", "system", "prune", "-af", "--volumes"], allow_fail=True)

    # journalctl vacuum (time + size)
    if have("journalctl"):
        keep_time = os.environ.get("CLEAN_JOURNAL_FOR", "7d")   # e.g. "7d"
        keep_size = os.environ.get("CLEAN_JOURNAL_SIZE", "200M")  # e.g. "200M"

        ctx.log(style(f"Vacuuming journal to {keep_time} and {keep_size}", C.GREY))
        ctx.run(["journalctl", f"--vacuum-time={keep_time}"], sudo=True, allow_fail=True)
        ctx.run(["journalctl", f"--vacuum-size={keep_size}"], sudo=True, allow_fail=True)

    # go mod cache
    if have("go"):
        ctx.run(["go", "clean", "-modcache"], allow_fail=True)

    # yarn cache
    if have("yarn"):
        ctx.run(["yarn", "cache", "clean"], allow_fail=True)

    # cargo-cache
    if have("cargo-cache"):
        ctx.run(["cargo", "cache", "-a"], allow_fail=True)

    # Flatpak repair (deeper cleanup)
    if have("flatpak"):
        ctx.run(["flatpak", "repair", "-y"], allow_fail=True)

    # Aggressive ~/.cache cleanup (except some whitelisted apps)
    if ctx.aggressive_cache:
        ctx.banner("Aggressive ~/.cache cleanup")
        base = Path.home() / ".cache"
        keep = {"qutebrowser", "mozilla", "chromium"}
        if base.is_dir():
            for child in base.iterdir():
                if child.name in keep:
                    ctx.log(style(f"Keeping cache: {child}", C.GREY))
                    continue
                ctx.run(["rm", "-rf", str(child)], allow_fail=True)


def remove_orphans(ctx: Ctx):
    """Remove Arch orphans if any."""
    if not have("pacman"):
        return

    ctx.banner("Orphaned packages (pacman -Qtdq)")

    try:
        proc = subprocess.run(
            ["pacman", "-Qtdq"],
            stdout=subprocess.PIPE,
            stderr=subprocess.DEVNULL,
            text=True,
        )
    except Exception as e:
        ctx.log(style(f"Failed to run pacman -Qtdq: {e}", C.RED))
        return

    output = proc.stdout.strip()
    if not output:
        ctx.log("No orphaned packages found.")
        return

    pkgs = [line.strip() for line in output.splitlines() if line.strip()]
    if not pkgs:
        ctx.log("No orphaned packages found.")
        return

    ctx.log(style(f"Found {len(pkgs)} orphan(s): {' '.join(pkgs)}", C.YEL))

    if not ctx.confirm(f"Remove these {len(pkgs)} orphans with pacman -Rns?"):
        ctx.log("Skipped orphan removal.")
        return

    cmd = ["pacman", "-Rns"]
    if ctx.assume_yes:
        cmd.append("--noconfirm")
    cmd.extend(pkgs)
    ctx.run(cmd, sudo=True, allow_fail=True)


# --------------------------------------------------------------------------
# Codex summarizer
# --------------------------------------------------------------------------

def tail_bytes(path: Path, n: int = 20000) -> str:
    """Return last n bytes of a file as string."""
    try:
        with path.open("rb") as f:
            f.seek(0, 2)
            size = f.tell()
            if size <= n:
                f.seek(0)
            else:
                f.seek(-n, 2)
            data = f.read()
        return data.decode("utf-8", errors="ignore")
    except Exception:
        try:
            return path.read_text(encoding="utf-8", errors="ignore")
        except Exception:
            return ""


def build_summary_prompt(log_text: str) -> str | None:
    """Construct the LLM prompt or return None if log is empty."""
    if not log_text or not log_text.strip():
        return None

    return textwrap.dedent(f"""
    Analyze the following system update log and produce a structured report.

    OUTPUT FORMAT (STRICT):
    - SUMMARY_OVERVIEW: 2–3 sentences, factual, no filler.
    - KEY_CHANGES: bullet list, grouped by manager (pacman, yay, apt, etc).
    - WARNINGS_ERRORS: bullet list or "None".
    - FOLLOW_UP_ACTIONS: bullet list or "None".
    - NOTABLE_DETAIL: exactly ONE concrete observation that may be easy to miss.

    RULES:
    - Do NOT use meta phrases like "Here is", "Interesting detail", or similar.
    - Do NOT add commentary outside the sections.
    - Keep tone technical and neutral.

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

        if ":" in line and line.split(":", 1)[0].isupper():
            if current:
                sections[current] = "\n".join(buf).strip()
            current = line.split(":", 1)[0]
            buf = [line.split(":", 1)[1].strip()]
        else:
            buf.append(line)

    if current:
        sections[current] = "\n".join(buf).strip()

    return sections


def select_terminal_section(sections: dict[str, str]) -> tuple[str, str]:
    priority = [
        "WARNINGS_ERRORS",
        "FOLLOW_UP_ACTIONS",
        "NOTABLE_DETAIL",
        "SUMMARY_OVERVIEW",
    ]

    for key in priority:
        content = sections.get(key)
        if content and content.lower() != "none":
            return key, content

    # Fallback
    return "SUMMARY_OVERVIEW", sections.get("SUMMARY_OVERVIEW", "")


def summarize_with_openai(ctx: Ctx, llm_enabled: bool) -> bool:
    if not llm_enabled:
        ctx.log("LLM summarization disabled (--no-llm).")
        return False

    ctx.banner("LLM Summary (OpenAI)")

    if ctx.dry_run:
        ctx.log("[DRY-RUN] Would summarize via OpenAI API")
        return True

    prompt = build_summary_prompt(tail_bytes(ctx.log_file))
    if prompt is None:
        ctx.log("No log content to summarize.")
        return False

    api_key = os.environ.get("OPENAI_API_KEY")
    if not api_key:
        ctx.log(style("OPENAI_API_KEY not set; skipping OpenAI summary.", C.RED))
        return False

    model = os.environ.get("OPENAI_MODEL", "gpt-4o-mini")
    url = "https://api.openai.com/v1/chat/completions"
    payload = {
        "model": model,
        "messages": [{"role": "user", "content": prompt}],
        "temperature": 0.2,
    }

    try:
        data = json.dumps(payload).encode("utf-8")
        req = urllib.request.Request(
            url,
            data=data,
            headers={
                "Content-Type": "application/json",
                "Authorization": f"Bearer {api_key}",
            },
        )
        with urllib.request.urlopen(req, timeout=20) as resp:
            text = resp.read().decode("utf-8", errors="ignore")
            parsed = json.loads(text)
    except Exception as e:
        ctx.log(style(f"OpenAI summary failed: {e}", C.RED))
        return False

    choices = parsed.get("choices") or []
    if not choices:
        ctx.log(style("OpenAI returned no choices.", C.RED))
        return False

    summary = (choices[0].get("message") or {}).get("content", "").strip()
    if not summary:
        ctx.log(style("OpenAI returned empty summary.", C.RED))
        return False

    ctx.summary_file.write_text(summary, encoding="utf-8")
    ctx.log(style(f"Summary saved to: {ctx.summary_file}", C.GREEN))

    sections = parse_summary_sections(summary)
    section_name, section_body = select_terminal_section(sections)

    ctx.log(style(f"\n[{section_name}]", C.B, C.CYAN))
    ctx.log(section_body)

    return True


def summarize_with_codex(ctx: Ctx, llm_enabled: bool):
    if not llm_enabled:
        ctx.log("LLM summarization disabled (--no-llm).")
        return False

    ctx.banner("LLM Summary (Codex)")

    if ctx.dry_run:
        ctx.log("[DRY-RUN] Would summarize via Codex CLI")
        return True

    prompt = build_summary_prompt(tail_bytes(ctx.log_file))
    if prompt is None:
        ctx.log("No log content to summarize.")
        return False

    if not have("codex"):
        ctx.log(style("Codex CLI not installed; skipping summary.", C.RED))
        return False

    try:
        proc = subprocess.run(
            ["codex", "exec", "--json"],
            input=prompt.encode("utf-8"),
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            timeout=30,
        )
    except Exception as e:
        ctx.log(style(f"Codex exec failed: {e}", C.RED))
        return False

    stdout_txt = proc.stdout.decode("utf-8", errors="ignore").strip()
    if proc.returncode != 0:
        ctx.log(style(f"Codex returned non-zero exit code {proc.returncode}", C.RED))
        stderr_txt = proc.stderr.decode("utf-8", errors="ignore").strip()
        if stderr_txt:
            ctx.log(style(f"Codex stderr:\n{stderr_txt}", C.RED))
        if stdout_txt:
            ctx.log(style("Using Codex stdout as fallback summary.", C.YEL))
            ctx.summary_file.write_text(stdout_txt, encoding="utf-8")
            ctx.log(style(f"Summary saved to: {ctx.summary_file}", C.GREEN))
        return False

    def parse_codex_json(raw: str):
        """Parse Codex JSON output, tolerating event streams and extra lines."""
        try:
            obj = json.loads(raw)
            if isinstance(obj, dict):
                return obj
        except json.JSONDecodeError:
            pass

        responses = []
        agent_items = []
        for line in raw.splitlines():
            line = line.strip()
            if not line:
                continue
            try:
                obj = json.loads(line)
            except json.JSONDecodeError:
                continue
            if not isinstance(obj, dict):
                continue
            if obj.get("response"):
                responses.append(str(obj["response"]).strip())
            item = obj.get("item") or {}
            if isinstance(item, dict) and item.get("text"):
                agent_items.append(str(item["text"]).strip())

        if responses:
            return {"response": responses[-1]}
        if agent_items:
            return {"response": agent_items[-1]}
        return None

    resp = parse_codex_json(stdout_txt)
    if resp is None:
        ctx.log(style("Codex JSON parse error: unable to parse response", C.RED))
        if stdout_txt:
            ctx.log(style("Using Codex stdout as fallback summary.", C.YEL))
            ctx.summary_file.write_text(stdout_txt, encoding="utf-8")
            ctx.log(style(f"Summary saved to: {ctx.summary_file}", C.GREEN))
        return False

    summary = resp.get("response", "").strip()
    if not summary:
        ctx.log(style("Codex returned empty summary.", C.RED))
        if stdout_txt:
            ctx.log(style("Using Codex stdout as fallback summary.", C.YEL))
            ctx.summary_file.write_text(stdout_txt, encoding="utf-8")
            ctx.log(style(f"Summary saved to: {ctx.summary_file}", C.GREEN))
        return bool(stdout_txt.strip())

    ctx.summary_file.write_text(summary, encoding="utf-8")
    ctx.log(style(f"Summary saved to: {ctx.summary_file}", C.GREEN))
    return True


# --------------------------------------------------------------------------
# Argument parsing / main
# --------------------------------------------------------------------------

def parse_args():
    p = argparse.ArgumentParser(
        description="Unified Arch/DietPi system updater with Codex summary",
        formatter_class=argparse.ArgumentDefaultsHelpFormatter,
    )

    p.add_argument("--system", action="store_true", help="Update system packages (pacman/apt/yay/paru)")
    p.add_argument("--flatpak", action="store_true", help="Update Flatpak apps")
    p.add_argument("--languages", action="store_true", help="Update language/dev package managers")
    p.add_argument("--containers", action="store_true", help="Update Docker images for running containers")

    p.add_argument("--no-llm", action="store_true", help="Disable Codex LLM summarization")
    p.add_argument("--dry-run", action="store_true", help="Print commands without executing")
    p.add_argument("--yes", "-y", dest="assume_yes", action="store_true", help="Assume yes to prompts")
    p.add_argument("--manual", dest="manual", action="store_true", help="Require confirmations (disable auto-yes)")
    p.add_argument("--no-clean", action="store_true", help="Skip cleanup steps")
    p.add_argument("--deep-clean", action="store_true", help="Perform extended cleanup (docker prune, journal vacuum, etc.)")

    p.add_argument("--remove-orphans", action="store_true", help="Remove orphaned packages on Arch (pacman -Qtdq & -Rns)")
    p.add_argument("--aggressive-cache", action="store_true", help="Aggressively clean ~/.cache (excluding some app caches)")

    p.add_argument("--log-dir", help="Override log directory (default: ~/Logs or $UPDATE_LOG_DIR)")
    p.add_argument("--clear-logs", action="store_true", help="Delete existing log files in the log directory before running")
    p.add_argument("--skip-git-repo-check", action="store_true", help="Allow running outside a Git worktree")
    p.add_argument("--npm-sudo", action="store_true", help="Run npm -g update with sudo")
    backend = p.add_mutually_exclusive_group()
    backend.add_argument("--use-openai", action="store_true", help="Use OpenAI API for summaries (default)")
    backend.add_argument("--use-codex", action="store_true", help="Use Codex CLI for summaries")

    args = p.parse_args()

    # Default: if no areas selected, run a full update and cleanup
    if not any([args.system, args.flatpak, args.languages, args.containers]):
        args.system = True
        args.flatpak = True
        args.languages = True
        args.containers = True
        args.deep_clean = True
        args.aggressive_cache = True

    # yes vs manual
    if args.manual:
        args.assume_yes = False
    else:
        if not args.assume_yes:
            # default to yes if neither flag used
            args.assume_yes = True

    return args


def main():
    args = parse_args()

    cwd = Path.cwd()
    if not args.skip_git_repo_check and not in_git_repo(cwd):
        print(
            style("Error: must run inside a Git worktree or pass --skip-git-repo-check.", C.RED),
            file=sys.stderr,
        )
        return 2

    # log directory
    log_dir_raw = args.log_dir or os.environ.get("UPDATE_LOG_DIR", "/home/braydenchaffee/Logs")
    log_dir = Path(log_dir_raw).expanduser()
    log_dir.mkdir(parents=True, exist_ok=True)
    if args.clear_logs:
        clear_log_dir(log_dir, assume_yes=args.assume_yes, dry_run=args.dry_run)

    ts = _dt.datetime.now().strftime("%Y%m%d-%H%M%S")
    log_file = log_dir / f"update-{ts}.log"
    summary_file = log_dir / f"update-{ts}.summary.txt"

    llm_backend = "openai"
    if args.use_codex:
        llm_backend = "codex"
    if args.use_openai:
        llm_backend = "openai"

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
        llm_backend=llm_backend,
    )

    ctx.log(style("=== Unified Arch/DietPi Update Tool ===", C.B, C.BLUE))
    ctx.log(f"Started: {_dt.datetime.now().isoformat(timespec='seconds')}")
    ctx.log(f"Host: {os.uname().nodename} | User: {os.environ.get('USER','unknown')}")
    ctx.log(
        "Flags: "
        f"system={args.system} flatpak={args.flatpak} languages={args.languages} containers={args.containers} "
        f"dry_run={args.dry_run} yes={args.assume_yes} clean={ctx.clean_after} deep={ctx.deep_clean} "
        f"llm={not args.no_llm} llm_backend={ctx.llm_backend} remove_orphans={args.remove_orphans} "
        f"aggressive_cache={args.aggressive_cache} npm_sudo={ctx.run_npm_sudo}"
    )
    ctx.log(f"Log file: {log_file}")

    try:
        if args.system:
            update_system(ctx)
        if args.flatpak:
            update_flatpak(ctx)
        if args.languages:
            update_languages(ctx)
        if args.containers:
            update_containers(ctx)

        ctx.log(f"Finished updates: {_dt.datetime.now().isoformat(timespec='seconds')}")

        if ctx.clean_after:
            cleanup(ctx)
            if ctx.deep_clean:
                cleanup_deep(ctx)

        if not args.no_llm:
            if ctx.llm_backend == "openai":
                ok = summarize_with_openai(ctx, llm_enabled=True)
                if not ok:
                    ctx.log(style("OpenAI summary failed; trying Codex fallback.", C.YEL))
                    summarize_with_codex(ctx, llm_enabled=True)
            else:
                ok = summarize_with_codex(ctx, llm_enabled=True)
                if not ok:
                    ctx.log(style("Codex summary failed; trying OpenAI fallback.", C.YEL))
                    summarize_with_openai(ctx, llm_enabled=True)

        if not args.dry_run:
            ctx.log(style(f"Full log: {log_file}", C.GREEN))
            if summary_file.exists() and summary_file.stat().st_size > 0:
                ctx.log(style(f"LLM summary: {summary_file}", C.GREEN))

        return 0

    except KeyboardInterrupt:
        ctx.log(style("Aborted by user (Ctrl+C).", C.RED))
        return 130
    except Exception as e:
        ctx.log(style(f"Unexpected error: {e}", C.RED))
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
