#!/usr/bin/env python3
"""
Unified system and developer package updater with LLM log summary (Python version)

Targets:
  - Arch Linux (pacman, yay, paru)
  - Debian/DietPi (apt-get)
Optional managers:
  - flatpak
  - docker
  - pipx, pip (user), npm -g, cargo, gem

LLM summarization chain (in order):
  1. LocalAI (OpenAI-compatible)
  2. Ollama
  3. text-generation-webui (OpenAI-compatible)
  4. text-generation-webui (native /api/v1/generate)
  5. OpenAI ChatGPT API (if OPENAI_API_KEY set)

Flags roughly mirror the previous bash script.
"""

import argparse
import datetime as _dt
import json
import os
import subprocess
import sys
import textwrap
from pathlib import Path
from typing import Optional, List, Dict

# -------- ANSI colors / styling -------- #

class Style:
  RESET = "\033[0m"
  BOLD = "\033[1m"
  DIM = "\033[2m"
  RED = "\033[31m"
  GREEN = "\033[32m"
  YELLOW = "\033[33m"
  BLUE = "\033[34m"
  CYAN = "\033[36m"
  GREY = "\033[90m"


def color(text: str, *styles: str) -> str:
  return "".join(styles) + str(text) + Style.RESET


# -------- Context / helpers -------- #

class Ctx:
  def __init__(
      self,
      dry_run: bool,
      assume_yes: bool,
      log_file: Path,
      summary_file: Path,
      model_name: str,
      ollama_host: str,
      ollama_port: int,
      localai_url: str,
      tgw_host: str,
      tgw_port: int,
      clean_after: bool,
      deep_clean: bool,
  ):
    self.dry_run = dry_run
    self.assume_yes = assume_yes
    self.log_file = log_file
    self.summary_file = summary_file
    self.model_name = model_name
    self.ollama_host = ollama_host
    self.ollama_port = ollama_port
    self.localai_url = localai_url.rstrip("/")
    self.tgw_host = tgw_host
    self.tgw_port = tgw_port
    self.clean_after = clean_after
    self.deep_clean = deep_clean

  def log(self, msg: str) -> None:
    """Log to both console and log file."""
    line = msg.rstrip("\n")
    print(line)
    try:
      with self.log_file.open("a", encoding="utf-8") as f:
        f.write(line + "\n")
    except Exception:
      # Logging failures should never kill the script
      pass

  def banner(self, title: str) -> None:
    bar = "=" * 20
    self.log(f"\n{bar} {title} {bar}")

  def confirm(self, question: str) -> bool:
    if self.assume_yes:
      self.log(color(f"[auto-yes] {question}", Style.GREY))
      return True
    try:
      reply = input(f"{question} [y/N]: ").strip().lower()
    except EOFError:
      return False
    return reply in ("y", "yes")

  def run(self, cmd: List[str], sudo: bool = False, allow_fail: bool = False) -> int:
    cmd_str = " ".join(cmd)
    if sudo:
      cmd = ["sudo"] + cmd
      cmd_str = "sudo " + cmd_str

    if self.dry_run:
      self.log(color(f"[DRY-RUN] + {cmd_str}", Style.GREY))
      return 0

    self.log(color(f"+ {cmd_str}", Style.GREY))
    try:
      result = subprocess.run(
          cmd,
          check=not allow_fail,
          text=True,
      )
      return result.returncode
    except subprocess.CalledProcessError as e:
      self.log(color(f"Command failed with exit code {e.returncode}: {cmd_str}", Style.RED))
      if allow_fail:
        return e.returncode
      raise
    except FileNotFoundError:
      self.log(color(f"Command not found: {cmd[0]}", Style.RED))
      if allow_fail:
        return 127
      raise


def have_cmd(name: str) -> bool:
  return subprocess.call(
      ["which", name],
      stdout=subprocess.DEVNULL,
      stderr=subprocess.DEVNULL,
  ) == 0


# -------- Update functions -------- #

def update_system(ctx: Ctx) -> None:
  ctx.banner("System packages")

  # Debian / DietPi
  if have_cmd("apt-get"):
    if ctx.confirm("Run apt-get update && apt-get upgrade?"):
      ctx.run(["apt-get", "update"], sudo=True)
      ctx.run(["apt-get", "upgrade", "-y"], sudo=True)
      ctx.run(["apt-get", "autoremove", "-y"], sudo=True, allow_fail=True)
      ctx.run(["apt-get", "autoclean", "-y"], sudo=True, allow_fail=True)
    else:
      ctx.log("Skipped apt-get")

  # Arch / pacman
  if have_cmd("pacman"):
    pac_args = ["pacman", "-Syu"]
    if ctx.assume_yes:
      pac_args.append("--noconfirm")
    if ctx.confirm(f"Run {' '.join(['sudo'] + pac_args)}?"):
      ctx.run(pac_args, sudo=True)
    else:
      ctx.log("Skipped pacman")

  # yay
  if have_cmd("yay"):
    yay_args = ["yay", "-Syu"]
    if ctx.assume_yes:
      yay_args.append("--noconfirm")
    if ctx.confirm(f"Run {' '.join(yay_args)}?"):
      ctx.run(yay_args)
    else:
      ctx.log("Skipped yay")

  # paru
  if have_cmd("paru"):
    paru_args = ["paru", "-Syu"]
    if ctx.assume_yes:
      paru_args.append("--noconfirm")
    if ctx.confirm(f"Run {' '.join(paru_args)}?"):
      ctx.run(paru_args)
    else:
      ctx.log("Skipped paru")


def update_flatpak(ctx: Ctx) -> None:
  ctx.banner("Flatpak")
  if not have_cmd("flatpak"):
    ctx.log("flatpak not installed")
    return
  if ctx.confirm("Run flatpak update?"):
    args = ["flatpak", "update"]
    if ctx.assume_yes:
      args.append("-y")
    ctx.run(args, allow_fail=True)
  else:
    ctx.log("Skipped flatpak")


def update_snap(ctx: Ctx) -> None:
  ctx.banner("Snap")
  if not have_cmd("snap"):
    ctx.log("snap not installed")
    return
  if ctx.confirm("Run snap refresh?"):
    ctx.run(["snap", "refresh"], sudo=True, allow_fail=True)
  else:
    ctx.log("Skipped snap")


def update_brew(ctx: Ctx) -> None:
  ctx.banner("Homebrew")
  if not have_cmd("brew"):
    ctx.log("brew not installed")
    return
  if ctx.confirm("Run brew update/upgrade/cleanup?"):
    ctx.run(["brew", "update"], allow_fail=True)
    ctx.run(["brew", "upgrade"], allow_fail=True)
    ctx.run(["brew", "cleanup", "-s"], allow_fail=True)
  else:
    ctx.log("Skipped brew")


def update_nix(ctx: Ctx) -> None:
  ctx.banner("Nix")
  if not have_cmd("nix"):
    ctx.log("nix not installed")
    return
  if not ctx.confirm("Update Nix profile?"):
    ctx.log("Skipped nix")
    return
  if have_cmd("nix"):
    ctx.run(["nix", "profile", "upgrade", "--all"], allow_fail=True)
  if have_cmd("nix-channel"):
    ctx.run(["nix-channel", "--update"], allow_fail=True)
  if have_cmd("nix-env"):
    ctx.run(["nix-env", "-u"], allow_fail=True)


def update_languages(ctx: Ctx) -> None:
  ctx.banner("Language & dev package managers")

  # pipx
  if have_cmd("pipx") and ctx.confirm("pipx upgrade --all?"):
    ctx.run(["pipx", "upgrade", "--all"], allow_fail=True)
  elif have_cmd("pipx"):
    ctx.log("Skipped pipx")

  # pip (user)
  python_bin = sys.executable or "python3"
  if ctx.confirm("Upgrade user pip packages (pip --user)?"):
    script = textwrap.dedent(
        """
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
            outdated = json.loads(out)
        except Exception:
            outdated = []

        for pkg in outdated:
            name = pkg.get("name")
            if not name:
                continue
            print(f"[pip] upgrading {name}...")
            try:
                subprocess.check_call([exe, "-m", "pip", "install", "--user", "--upgrade", name])
            except subprocess.CalledProcessError:
                print(f"[pip] failed to upgrade {name}")
        """
    )
    if ctx.dry_run:
      ctx.log(color("[DRY-RUN] Would run Python pip-upgrade snippet", Style.GREY))
    else:
      ctx.log("[pip] checking for outdated user packages...")
      ctx.run([python_bin, "-c", script], allow_fail=True)
  else:
    ctx.log("Skipped pip user upgrades")

  # npm global
  if have_cmd("npm") and ctx.confirm("npm -g update?"):
    ctx.run(["npm", "-g", "update"], allow_fail=True)
  elif have_cmd("npm"):
    ctx.log("Skipped npm")

  # cargo
  if have_cmd("cargo"):
    if have_cmd("cargo-install-update") and ctx.confirm("cargo install-update -a?"):
      ctx.run(["cargo", "install-update", "-a"], allow_fail=True)
    elif have_cmd("cargo-install-update"):
      ctx.log("Skipped cargo-install-update")
    else:
      ctx.log("cargo-install-update not installed; skipping cargo updates")

  # gem
  if have_cmd("gem") and ctx.confirm("gem update (user)?"):
    ctx.run(["gem", "update", "--user-install"], allow_fail=True)
  elif have_cmd("gem"):
    ctx.log("Skipped gem")


def update_containers(ctx: Ctx) -> None:
  ctx.banner("Containers")
  if not have_cmd("docker"):
    ctx.log("docker not installed")
    return
  if not ctx.confirm("Pull newer images for running Docker containers?"):
    ctx.log("Skipped docker pulls")
    return
  cmd = ["bash", "-c", "docker ps --format '{{.Image}}' | xargs -r -n1 docker pull"]
  ctx.run(cmd, allow_fail=True)
  ctx.log("Hint: restart containers manually if necessary.")


# -------- Cleanup functions -------- #

def cleanup_caches(ctx: Ctx) -> None:
  ctx.banner("Cleanup (caches)")

  # pacman cache
  if have_cmd("pacman"):
    if have_cmd("paccache"):
      ctx.run(["paccache", "-rk0"], sudo=True, allow_fail=True)
      ctx.run(["paccache", "-ruk0"], sudo=True, allow_fail=True)
    else:
      ctx.run(["pacman", "-Scc", "--noconfirm"], sudo=True, allow_fail=True)

  # yay/paru/pikaur caches
  for path in [
      Path.home() / ".cache" / "yay",
      Path.home() / ".cache" / "paru",
      Path.home() / ".cache" / "pikaur",
  ]:
    if path.exists():
      ctx.run(["rm", "-rf", str(path)], allow_fail=True)

  # flatpak unused
  if have_cmd("flatpak"):
    ctx.run(["flatpak", "uninstall", "--unused", "-y"], allow_fail=True)

  # npm cache
  if have_cmd("npm"):
    ctx.run(["npm", "cache", "clean", "--force"], allow_fail=True)

  # pip cache
  ctx.run([sys.executable or "python3", "-m", "pip", "cache", "purge"], allow_fail=True)


def cleanup_deep(ctx: Ctx) -> None:
  ctx.banner("Deep Cleanup")

  # docker prune
  if have_cmd("docker"):
    ctx.run(["docker", "system", "prune", "-af", "--volumes"], allow_fail=True)

  # journalctl vacuum
  journal_for = os.environ.get("CLEAN_JOURNAL_FOR", "7d")
  if have_cmd("journalctl"):
    # Try time first, then size
    if ctx.run(["journalctl", f"--vacuum-time={journal_for}"], sudo=True, allow_fail=True) != 0:
      ctx.run(["journalctl", f"--vacuum-size={journal_for}"], sudo=True, allow_fail=True)

  # go module cache
  if have_cmd("go"):
    ctx.run(["go", "clean", "-modcache"], allow_fail=True)

  # yarn cache
  if have_cmd("yarn"):
    ctx.run(["yarn", "cache", "clean"], allow_fail=True)

  # cargo cache via cargo-cache
  if have_cmd("cargo-cache"):
    ctx.run(["cargo", "cache", "-a"], allow_fail=True)


# -------- HTTP helper (stdlib) -------- #

def http_post_json(url: str, payload: Dict, timeout: float = 10.0) -> Optional[Dict]:
  import urllib.request
  import urllib.error

  data = json.dumps(payload).encode("utf-8")
  req = urllib.request.Request(url, data=data, headers={"Content-Type": "application/json"})
  try:
    with urllib.request.urlopen(req, timeout=timeout) as resp:
      text = resp.read().decode("utf-8", errors="ignore")
      return json.loads(text)
  except (urllib.error.URLError, urllib.error.HTTPError, json.JSONDecodeError):
    return None


# -------- LLM summarization -------- #

def tail_log_bytes(path: Path, num_bytes: int = 12000) -> str:
  try:
    with path.open("rb") as f:
      f.seek(0, 2)
      size = f.tell()
      if size <= num_bytes:
        f.seek(0)
        chunk = f.read()
      else:
        f.seek(-num_bytes, 2)
        chunk = f.read()
    return chunk.decode("utf-8", errors="ignore")
  except Exception:
    try:
      return path.read_text(encoding="utf-8", errors="ignore")
    except Exception:
      return ""


def read_log_full(path: Path) -> str:
  """Read the full log; fall back to a tail if the file cannot be fully read."""
  try:
    return path.read_text(encoding="utf-8", errors="ignore")
  except Exception:
    return tail_log_bytes(path)


def summarize_with_llm(ctx: Ctx, enabled: bool) -> None:
  if not enabled:
    ctx.log("LLM summarization disabled (--no-llm).")
    return

  if ctx.dry_run:
    ctx.log("[DRY-RUN] Would summarize log via LLM chain.")
    return

  if not ctx.log_file.exists() or ctx.log_file.stat().st_size == 0:
    ctx.log("No log content to summarize.")
    return

  ctx.banner("LLM Summary")

  log_snippet = read_log_full(ctx.log_file)

  prompt = textwrap.dedent(
      """\
      You are a meticulous system maintenance assistant. Create a concise but detailed summary of this full update log for a power user.

      Required sections (omit only if empty):
      - Issues: failed packages/commands, repo/key/SSL errors, prompts that were skipped, partial upgrades, pacnew/pacsave notices.
      - Package changes (group by manager): include package -> version changes when present; call out kernel/firmware/driver updates.
      - Services/daemons: restarts performed or needed (systemd services, containers, desktop components); include commands if implied.
      - Follow-ups: manual steps, configs to review, rerun commands, reboots/restarts required (state why).
      - Cleanup/disk: cache removals, prunes, notable disk usage impacts.

      Use terse, technical language. Do not lose important details from the log; prefer briefly listing specifics over vague summaries.

      BEGIN LOG SNIPPET
      """
  )
  prompt_full = f"{prompt}\n{log_snippet}\nEND LOG SNIPPET"

  summary: Optional[str] = None

  # 1) LocalAI (OpenAI-compatible)
  localai_chat_url = f"{ctx.localai_url}/v1/chat/completions"
  ctx.log(color(f"→ Trying LocalAI at {localai_chat_url} (model={ctx.model_name})", Style.CYAN))
  payload = {
      "model": ctx.model_name,
      "messages": [
          {"role": "system", "content": "You are a helpful system maintenance assistant."},
          {"role": "user", "content": prompt_full},
      ],
      "temperature": 0.2,
  }
  resp = http_post_json(localai_chat_url, payload, timeout=12.0)
  if resp and "choices" in resp and resp["choices"]:
    summary = resp["choices"][0]["message"]["content"]
    ctx.log(color("✔ LocalAI succeeded", Style.GREEN))
  else:
    ctx.log(color("✘ LocalAI failed; falling back to Ollama...", Style.YELLOW))

  # 2) Ollama
  if summary is None:
    ollama_url = f"http://{ctx.ollama_host}:{ctx.ollama_port}/api/generate"
    ctx.log(color(f"→ Trying Ollama at {ollama_url} (model={ctx.model_name})", Style.CYAN))
    payload = {
        "model": ctx.model_name,
        "prompt": prompt_full,
        "stream": False,
        "temperature": 0.2,
    }
    resp = http_post_json(ollama_url, payload, timeout=10.0)
    if resp and "response" in resp:
      summary = resp["response"]
      ctx.log(color("✔ Ollama succeeded", Style.GREEN))
    else:
      ctx.log(color("✘ Ollama failed; trying text-generation-webui (OpenAI)...", Style.YELLOW))

  # 3) text-generation-webui OpenAI-compatible
  if summary is None:
    tgw_url = f"http://{ctx.tgw_host}:{ctx.tgw_port}/v1/chat/completions"
    ctx.log(color(f"→ Trying TGW OpenAI-compat at {tgw_url}", Style.CYAN))
    payload = {
        "model": ctx.model_name,
        "messages": [{"role": "user", "content": prompt_full}],
        "temperature": 0.2,
    }
    resp = http_post_json(tgw_url, payload, timeout=8.0)
    if resp and "choices" in resp and resp["choices"]:
      summary = resp["choices"][0]["message"]["content"]
      ctx.log(color("✔ TGW OpenAI-compat succeeded", Style.GREEN))
    else:
      ctx.log(color("✘ TGW OpenAI-compat failed; trying TGW native...", Style.YELLOW))

  # 4) text-generation-webui native /api/v1/generate
  if summary is None:
    tgw_native_url = f"http://{ctx.tgw_host}:{ctx.tgw_port}/api/v1/generate"
    ctx.log(color(f"→ Trying TGW native at {tgw_native_url}", Style.CYAN))
    payload = {
        "prompt": prompt_full,
        "max_new_tokens": 256,
        "temperature": 0.2,
        "stop": ["</s>"],
    }
    resp = http_post_json(tgw_native_url, payload, timeout=8.0)
    if resp and "results" in resp and resp["results"]:
      summary = resp["results"][0].get("text", "")
      ctx.log(color("✔ TGW native succeeded", Style.GREEN))
    else:
      ctx.log(color("✘ TGW native failed; final fallback OpenAI...", Style.YELLOW))

  # 5) Final fallback: OpenAI API (if key present)
  if summary is None:
    api_key = os.environ.get("OPENAI_API_KEY")
    if not api_key:
      ctx.log("OPENAI_API_KEY not set; cannot use OpenAI fallback.")
    else:
      ctx.log(color("→ Trying OpenAI ChatGPT API", Style.CYAN))
      openai_url = "https://api.openai.com/v1/chat/completions"
      payload = {
          "model": "gpt-4o-mini",
          "messages": [{"role": "user", "content": prompt_full}],
          "temperature": 0.2,
      }
      import urllib.request
      import urllib.error
      try:
        data = json.dumps(payload).encode("utf-8")
        req = urllib.request.Request(
            openai_url,
            data=data,
            headers={
                "Content-Type": "application/json",
                "Authorization": f"Bearer {api_key}",
            },
        )
        with urllib.request.urlopen(req, timeout=12.0) as resp:
          text = resp.read().decode("utf-8", errors="ignore")
          parsed = json.loads(text)
          if parsed.get("choices"):
            summary = parsed["choices"][0]["message"]["content"]
            ctx.log(color("✔ OpenAI fallback succeeded", Style.GREEN))
      except Exception as e:
        ctx.log(color(f"✘ OpenAI fallback failed: {e}", Style.RED))

  if summary:
    ctx.summary_file.parent.mkdir(parents=True, exist_ok=True)
    ctx.summary_file.write_text(summary, encoding="utf-8")
    ctx.log(color(f"Summary saved to: {ctx.summary_file}", Style.GREEN))
  else:
    ctx.log(color("All LLM backends failed. No summary generated.", Style.RED))


# -------- Argument parsing / main -------- #

def parse_args(argv: Optional[List[str]] = None) -> argparse.Namespace:
  parser = argparse.ArgumentParser(
      description="Unified system + dev package updater with LLM log summary",
      formatter_class=argparse.ArgumentDefaultsHelpFormatter,
  )

  parser.add_argument("--system", action="store_true", help="Update system packages (pacman/apt etc.)")
  parser.add_argument("--flatpak", action="store_true", help="Update Flatpak apps")
  parser.add_argument("--snap", action="store_true", help="Update Snap packages")
  parser.add_argument("--brew", action="store_true", help="Update Homebrew")
  parser.add_argument("--nix", action="store_true", help="Update Nix profile")
  parser.add_argument("--languages", action="store_true", help="Update language/dev package managers")
  parser.add_argument("--containers", action="store_true", help="Update Docker images")

  parser.add_argument("--no-llm", action="store_true", help="Disable LLM summarization")
  parser.add_argument("--model", default=os.environ.get("LLM_MODEL", "llama3.1"), help="LLM model name")
  parser.add_argument("--dry-run", action="store_true", help="Print commands without executing them")
  parser.add_argument("--yes", "-y", dest="assume_yes", action="store_true", help="Assume yes to all prompts")
  parser.add_argument("--manual", dest="manual", action="store_true", help="Require confirmations")
  parser.add_argument("--no-clean", dest="no_clean", action="store_true", help="Skip cache cleanup")
  parser.add_argument("--deep-clean", dest="deep_clean", action="store_true", help="Perform deep cleanup")
  parser.add_argument("--log-dir", dest="log_dir", help="Override log directory (default: ./logs)")

  args = parser.parse_args(argv)

  # Default behaviors: system updates on if nothing specified
  if not any([args.system, args.flatpak, args.snap, args.brew, args.nix, args.languages, args.containers]):
    args.system = True

  # yes vs manual
  if args.manual:
    args.assume_yes = False
  else:
    if not args.assume_yes:
      # default yes if neither flag used (mirror bash)
      args.assume_yes = True

  return args


def main(argv: Optional[List[str]] = None) -> int:
  args = parse_args(argv)

  # Determine log directory
  log_dir_env = os.environ.get("UPDATE_LOG_DIR")
  if args.log_dir:
    log_dir = Path(args.log_dir)
  elif log_dir_env:
    log_dir = Path(log_dir_env)
  else:
    log_dir = Path("logs")
  log_dir.mkdir(parents=True, exist_ok=True)

  timestamp = _dt.datetime.now().strftime("%Y%m%d-%H%M%S")
  log_file = log_dir / f"update-{timestamp}.log"
  summary_file = log_dir / f"update-{timestamp}.summary.txt"

  ollama_host = os.environ.get("LLM_OLLAMA_HOST", "192.168.1.69")
  ollama_port = int(os.environ.get("LLM_OLLAMA_PORT", "11434"))
  localai_url = os.environ.get("LLM_LOCALAI_URL", "http://localhost:8080")
  tgw_host = os.environ.get("LLM_TGW_HOST", "192.168.1.69")
  tgw_port = int(os.environ.get("LLM_TGW_PORT", "5150"))

  ctx = Ctx(
      dry_run=args.dry_run,
      assume_yes=args.assume_yes,
      log_file=log_file,
      summary_file=summary_file,
      model_name=args.model,
      ollama_host=ollama_host,
      ollama_port=ollama_port,
      localai_url=localai_url,
      tgw_host=tgw_host,
      tgw_port=tgw_port,
      clean_after=not args.no_clean,
      deep_clean=args.deep_clean,
  )

  ctx.log(color("=== Unified Update Tool (Python) ===", Style.BOLD, Style.BLUE))
  ctx.log(f"Started: {_dt.datetime.now().isoformat(timespec='seconds')}")
  ctx.log(f"Host: {os.uname().nodename} | User: {os.environ.get('USER', 'unknown')}")
  ctx.log(
      f"Flags: system={args.system} flatpak={args.flatpak} snap={args.snap} "
      f"brew={args.brew} nix={args.nix} lang={args.languages} containers={args.containers} "
      f"dry_run={args.dry_run} yes={args.assume_yes} clean={ctx.clean_after} "
      f"deep={ctx.deep_clean} llm={not args.no_llm} model={ctx.model_name}"
  )
  ctx.log(f"Log file: {log_file}")

  try:
    if args.system:
      update_system(ctx)
    if args.flatpak:
      update_flatpak(ctx)
    if args.snap:
      update_snap(ctx)
    if args.brew:
      update_brew(ctx)
    if args.nix:
      update_nix(ctx)
    if args.languages:
      update_languages(ctx)
    if args.containers:
      update_containers(ctx)

    ctx.log(f"Finished updates: {_dt.datetime.now().isoformat(timespec='seconds')}")

    if ctx.clean_after:
      cleanup_caches(ctx)
      if ctx.deep_clean:
        cleanup_deep(ctx)

    summarize_with_llm(ctx, enabled=not args.no_llm)

    if not args.dry_run:
      ctx.log(color(f"Full log: {log_file}", Style.GREEN))
      if summary_file.exists() and summary_file.stat().st_size > 0:
        ctx.log(color(f"LLM summary: {summary_file}", Style.GREEN))

    return 0

  except KeyboardInterrupt:
    ctx.log(color("\nAborted by user (Ctrl+C).", Style.RED))
    return 130
  except Exception as e:
    ctx.log(color(f"Unexpected error: {e}", Style.RED))
    return 1


if __name__ == "__main__":
  raise SystemExit(main())
