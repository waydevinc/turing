#!/usr/bin/env bash
# Installs turing (AI line attribution → WD: commit trailer) for every AI agent found, plus OTel telemetry for Claude Code / OpenCode.
# macOS / Linux / Git Bash. Usage: ./install.sh [--agents claude,opencode,cursor,gemini,copilot,droid,codex] [--no-otel]
#                                                [--uninstall | --diagnose] [dir]   (dir defaults to the current folder)
# Non-interactive OTel: set TURING_CLAUDE_TOKEN / TURING_OPENCODE_TOKEN (optional: TURING_OTEL_URL, and TURING_EMAIL to use one email for every repo).
set -euo pipefail

here="$(cd "$(dirname "$0")" && pwd)"
dest="$HOME/.waydev/turing.js"
default_url="https://api-ai.waydev.co"
mode=install otel=1 dir="$PWD" agents=""

while [ $# -gt 0 ]; do
  a="$1"; shift
  case "$a" in
    --agents) agents="${1:-}"; shift ;;
    --agents=*) agents="${a#--agents=}" ;;
    --uninstall) mode=uninstall ;;
    --diagnose) mode=diagnose ;;
    --no-otel) otel=0 ;;
    -h|--help) sed -n '2,5p' "$0"; exit 0 ;;
    -*) echo "unknown option: $a" >&2; exit 1 ;;
    *) dir="$a" ;;
  esac
done

for c in node git; do
  command -v "$c" >/dev/null 2>&1 || { echo "$c is required but not on PATH" >&2; exit 1; }
done

if [ "$mode" = diagnose ]; then
  if [ -f "$dest" ]; then exec node "$dest" diagnose "$dir"; else exec node "$here/turing.js" diagnose "$dir"; fi
fi

if [ "$mode" = uninstall ]; then
  [ -f "$dest" ] || { echo "turing is not installed."; exit 0; }
  echo "Removing git hooks and OTel settings from repos under $dir:"
  node "$dest" disable "$dir"
  node "$dest" teardown
  rm -rf "$HOME/.waydev/turing" "$dest"
  echo "Done."
  exit 0
fi

[ -n "$agents" ] || agents="$(node "$here/turing.js" agents | tr ' ' ',')"
[ -n "$agents" ] || { echo "no supported AI agent found; pass --agents to choose" >&2; exit 1; }
flags=()
IFS=',' read -r -a list <<< "$agents"
for a in "${list[@]}"; do flags+=("--$a"); done
has() { case ",$agents," in *",$1,"*) return 0 ;; esac; return 1; }
echo "Agents: ${agents//,/, }"

echo "Repositories under $dir:"
repos="$(node "$here/turing.js" repos "$dir")"
[ -n "$repos" ] || { echo "  none found"; exit 1; }
printf '%s\n' "$repos"

entire_repos="$(node "$here/turing.js" entire-repos "$dir")" entire=""
if [ -n "$entire_repos" ]; then
  echo
  echo "Entire is set up in:"
  printf '%s\n' "$entire_repos"
  echo "Both tools write a WD: trailer. Removing Entire runs its uninstall (its .entire/ folder, session data and shadow"
  echo "branches go too) and removes install-wd's wd_commit_hook. Keeping it puts turing in compare mode (WD-Turing: trailer)."
  read -r -p "Remove Entire from these repos? [y/N] " reply || true
  case "$reply" in [yY]*) entire=remove ;; *) entire=keep ;; esac
fi

ask_token() { # $1=label $2=env var name
  local tok="${!2:-}"
  while [ -z "$tok" ]; do
    read -r -s -p "$1 ingest token: " tok; echo
  done
  export "$2=$tok"
}

has claude || has opencode || otel=0
if [ "$otel" = 1 ]; then
  echo
  echo "OTel telemetry sends usage, tokens and cost to Waydev (skip with --no-otel)."
  if [ -z "${TURING_OTEL_URL:-}" ]; then
    read -r -p "Ingest URL [$default_url]: " url || true
    export TURING_OTEL_URL="${url:-$default_url}"
  fi
  if has claude; then ask_token "Claude Code" TURING_CLAUDE_TOKEN; fi
  if has opencode; then ask_token "OpenCode" TURING_OPENCODE_TOKEN; fi
  if [ -z "${TURING_EMAIL:-}" ]; then
    git_email="$(git config --global user.email || true)"
    prompt="Email for OTel: "
    if [ -n "$git_email" ]; then prompt="Email for OTel (Enter = each repo's git user.email, e.g. $git_email): "; fi
    email=""
    until [[ "$email" == ?*@?*.?* ]]; do
      read -r -p "$prompt" email || exit 1
      if [ -z "$email" ] && [ -n "$git_email" ]; then break; fi
    done
    if [ -n "$email" ]; then export TURING_EMAIL="$email"; fi
  fi
else
  unset TURING_CLAUDE_TOKEN TURING_OPENCODE_TOKEN
fi

echo
read -r -p "Install turing$([ "$otel" = 1 ] && printf ' with OTel') in these repos? [Y/n] " reply || true
case "$reply" in [nN]*) echo "Aborted."; exit 0 ;; esac

node "$here/turing.js" setup "${flags[@]}"
if [ "$entire" = remove ]; then
  echo "Removing Entire:"
  node "$dest" remove-entire "$dir"
elif [ "$entire" = keep ]; then
  while read -r r; do node "$dest" enable --compare "$r" >/dev/null; done <<< "$entire_repos"
fi
node "$dest" enable "$dir"
echo "Done. Check the install with: ./install.sh --diagnose \"$dir\""
