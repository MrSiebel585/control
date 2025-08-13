#!/bin/bash
# ─── OMNISCIENT FRAMEWORK CLI ───────────────────────────────────────────────
# Base: user-provided scaffold + prominent features migrated intelligently

set -Eeuo pipefail

# ── Version / Paths ──────────────────────────────────────────────────────────
OMNISCIENTCTL_VERSION="1.1.0"
OMNIROOT="/opt/omniscient"

# Environment (safe auto-source)
[[ -f "$OMNIROOT/.env" ]] && source "$OMNIROOT/.env" || true
[[ -f "$OMNIROOT/.autoenv/activate.sh" ]] && source "$OMNIROOT/.autoenv/activate.sh" || true

# Directories (keep your categories)
SCRIPT_DIRS=("ai" "core" "bin" "menus" "modules" "malformed" "offensive" "system" "scripts" "osint" "logs")
OMNIDIR="$OMNIROOT/control/omniscientctl.d"

# Files
CONF="$OMNIROOT/omniscient.conf"
LOG="$OMNIROOT/logs/omniscientctl.log"
PROMPT_LOG="${PROMPT_LOG:-$OMNIROOT/logs/prompt.log}"
SUMMARY_LOG="${SUMMARY_LOG:-$OMNIROOT/logs/ai_summary.log}"
PERIODIC_MAINTENANCE="${PERIODIC_MAINTENANCE:-$OMNIROOT/init/cleanup.sh}"

# Defaults / fallbacks
MODEL="${MODEL:-gpt4all}"
LOG_LEVEL="${LOG_LEVEL:-INFO}"
OLLAMA_API="${OLLAMA_API:-http://localhost:11434/api/generate}"
SERVICES_TO_ENABLE="${SERVICES_TO_ENABLE:-apache2,mysql}"
DRY_RUN="${DRY_RUN:-0}"
ASSUME_YES="${ASSUME_YES:-0}"

mkdir -p "$(dirname "$LOG")" "$(dirname "$PROMPT_LOG")" "$(dirname "$SUMMARY_LOG")"
echo "[+] OmniscientCTL invoked at $(date) with args: $*" >> "$LOG"

# ── Utilities ────────────────────────────────────────────────────────────────
die() { echo "[✘] $*" | tee -a "$LOG" >&2; exit 1; }
log_action() { echo "[$(date +'%F %T')] $*" | tee -a "$PROMPT_LOG"; }
need() { command -v "$1" >/dev/null 2>&1 || die "Missing required command: $1"; }
ynflag() { [[ "$ASSUME_YES" == "1" ]] && echo "-y" || true; }
run() {
  if [[ "$DRY_RUN" == "1" ]]; then
    log_action "[DRY-RUN] $*"
  else
    log_action "[RUN] $*"
    eval "$@"
  fi
}

# Strip CRLF if the file got edited on Windows (best-effort, one-time)
if file "$0" 2>/dev/null | grep -qi "CRLF"; then
  sed -i 's/\r$//' "$0" || true
fi

# ── Load drop-in shell modules (your extension point) ────────────────────────
if [[ -d "$OMNIDIR" ]]; then
  shopt -s nullglob
  for f in "$OMNIDIR"/*.bash; do
    [[ -f "$f" ]] && source "$f"
  done
  shopt -u nullglob
fi

# ── Config load (crudini optional) ───────────────────────────────────────────
if command -v crudini &>/dev/null && [[ -f "$CONF" ]]; then
  MODEL=$(crudini --get "$CONF" models MODEL_BACKEND 2>/dev/null || echo "$MODEL")
  LOG_LEVEL=$(crudini --get "$CONF" core LOG_LEVEL 2>/dev/null || echo "$LOG_LEVEL")
  OLLAMA_API=$(crudini --get "$CONF" ollama API_URL 2>/dev/null || echo "$OLLAMA_API")
  SERVICES_TO_ENABLE=$(crudini --get "$CONF" core SERVICES 2>/dev/null || echo "$SERVICES_TO_ENABLE")
fi

# ── Activate Python virtual environment (search common paths) ────────────────
if [[ -z "${VIRTUAL_ENV:-}" ]]; then
  for path in "$OMNIROOT/venv/bin/activate" "$OMNIROOT/bin/activate" "$OMNIROOT/.env/bin/activate"; do
    [[ -f "$path" ]] && source "$path" && break
  done
fi

# ── Auto-register modules (mod_*.sh) ─────────────────────────────────────────
MODULE_DIR="$OMNIROOT/modules"
declare -A MODULES=()
if [[ -d "$MODULE_DIR" ]]; then
  shopt -s nullglob
  for mod_file in "$MODULE_DIR"/mod_*.sh; do
    [[ -f "$mod_file" ]] || continue
    mod_basename=$(basename "$mod_file" .sh)
    mod_name=${mod_basename#mod_}
    enabled="true"
    if command -v crudini &>/dev/null && [[ -f "$CONF" ]]; then
      enabled=$(crudini --get "$CONF" modules "$mod_name" 2>/dev/null || echo "true")
    fi
    if [[ "$enabled" == "true" ]]; then
      source "$mod_file"
      MODULES["$mod_name"]="mod_${mod_name}"
    fi
  done
  shopt -u nullglob
fi

# ── Core Actions (your originals + tidy) ─────────────────────────────────────
restart_services() {
  log_action "Restarting core services: $SERVICES_TO_ENABLE"
  IFS=',' read -ra SERVICES <<< "$SERVICES_TO_ENABLE"
  for service in "${SERVICES[@]}"; do
    echo "Restarting $service..."
    run "sudo systemctl restart '$service'"
  done
  show_menu
}

stop_services() {
  log_action "Stopping core services: $SERVICES_TO_ENABLE"
  IFS=',' read -ra SERVICES <<< "$SERVICES_TO_ENABLE"
  for service in "${SERVICES[@]}"; do
    echo "Stopping $service..."
    run "sudo systemctl stop '$service'"
  done
  show_menu
}

start_services() {
  log_action "Starting core services: $SERVICES_TO_ENABLE"
  IFS=',' read -ra SERVICES <<< "$SERVICES_TO_ENABLE"
  for service in "${SERVICES[@]}"; do
    echo "Starting $service..."
    run "sudo systemctl start '$service'"
  done
  show_menu
}

health_check() {
  log_action "Checking health of core services"
  IFS=',' read -ra SERVICES <<< "$SERVICES_TO_ENABLE"
  for service in "${SERVICES[@]}"; do
    STATUS=$(systemctl is-active "$service" || true)
    echo "$service → $STATUS"
  done
  show_menu
}

run_plugins() {
  local plugin_dir="${OMNISCIENT_PLUGIN_DIR:-$OMNIROOT/plugins}"
  echo -e "\n🗉 Executing plugins in $plugin_dir"
  shopt -s nullglob
  for plugin in "$plugin_dir"/*.sh; do
    if [[ -x "$plugin" ]]; then
      echo "→ Running $(basename "$plugin")"
      bash "$plugin"
    fi
  done
  shopt -u nullglob
  show_menu
}

browse_directories() {
  echo -e "\n📂 Available Script Categories:"
  select dir in "${SCRIPT_DIRS[@]}" "Back"; do
    if [[ "$REPLY" == $(( ${#SCRIPT_DIRS[@]} + 1 )) ]]; then show_menu; return; fi
    TARGET="$OMNIROOT/$dir"
    if [[ -d "$TARGET" ]]; then
      echo -e "\n📁 $dir Directory Contents:"
      mapfile -t files < <(find "$TARGET" -maxdepth 1 -type f \( -name "*.sh" -o -name "*.bash" \))
      if [[ ${#files[@]} -eq 0 ]]; then echo "No scripts in $TARGET"; continue; fi
      select file in "${files[@]}" "Back"; do
        if [[ "$REPLY" == $(( ${#files[@]} + 1 )) ]]; then browse_directories; return; fi
        if [[ -f "$file" ]]; then
          echo -e "\n🚀 Executing: $file\n"
          log_action "Executing user script: $file"
          bash "$file"
          break
        fi
        echo "Invalid selection. Try again."
      done
    else
      echo "[✘] Directory not found: $TARGET"
    fi
    break
  done
}

view_environment() {
  log_action "Displaying Omniscient environment"
  env | grep -E 'OMNISCIENT_|SUMMARY_LOG|PROMPT_LOG|DEFAULT_MODEL|OLLAMA_API|IP_ADDRESS|GATEWAY|DNS_SERVERS' || true
  echo "OMNIROOT=$OMNIROOT"
  echo "MODEL=$MODEL"
  echo "OLLAMA_API=$OLLAMA_API"
  show_menu
}

run_summary() {
  log_action "Invoking AI summary process..."
  echo "[AI] Generating daily summary..."
  echo "[$(date +'%F %T')] Auto summary: All systems nominal." >> "$SUMMARY_LOG"
  sleep 1
  show_menu
}

trigger_maintenance() {
  log_action "Triggering scheduled maintenance via: $PERIODIC_MAINTENANCE"
  if [[ -x "$PERIODIC_MAINTENANCE" ]]; then
    bash "$PERIODIC_MAINTENANCE"
  else
    echo "Maintenance script not found or not executable."
  fi
  show_menu
}

show_status() {
  log_action "Gathering system status info"
  echo "Uptime: $(uptime -p || true)"
  echo "IP: $(hostname -I 2>/dev/null | awk '{print $1}')"
  echo "Disk:"; df -h | awk 'NR==1 || /\/$|\/opt|\/var/'
  echo "Memory:"; free -h | grep -v Swap
  show_menu
}

# ── AI Prompt (Ollama/OpenAI/GPT4All) ────────────────────────────────────────
do_prompt() {
  local prompt_text="$1"
  local engine="${2:-$MODEL}"

  if [[ "$engine" == "ollama" ]]; then
    need curl
    if command -v jq &>/dev/null; then
      payload=$(jq -n --arg m "$MODEL" --arg p "$prompt_text" '{model:$m, prompt:$p}')
    else
      esc=${prompt_text//\"/\\\"}
      payload="{\"model\":\"$MODEL\",\"prompt\":\"$esc\"}"
    fi
    resp=$(curl -s -X POST "$OLLAMA_API" -H "Content-Type: application/json" -d "$payload")
    if command -v jq &>/dev/null; then
      echo -e "\033[1;32mAI (Ollama):\033[0m $(echo "$resp" | jq -r '.response // .result // .message // .output // .[]?')"
    else
      echo -e "\033[1;32mAI (Ollama):\033[0m $resp"
    fi
  elif [[ "$engine" == "openai" ]]; then
    python3 - "$prompt_text" <<'PY'
import os, sys
try:
  import openai
except Exception:
  print("openai package not installed", file=sys.stderr); sys.exit(1)
prompt = sys.argv[1]
model = os.getenv("MODEL", "gpt-4o-mini")
openai.api_key = os.getenv("OPENAI_API_KEY")
resp = openai.ChatCompletion.create(model=model, messages=[{'role':'user','content':prompt}])
print(resp.choices[0].message.content.strip())
PY
  else
    python3 "$OMNIROOT/ai/tools/run_gpt4all_prompt.py" "$prompt_text"
  fi
}

# ── Namespaced SysAdmin Wrappers ─────────────────────────────────────────────
pkg_router() {
  local sub="${1:-}"; shift || true
  case "$sub" in
    update) need apt-get; run "sudo apt-get update && sudo apt-get upgrade $(ynflag)";;
    install) need apt-get; [[ $# -ge 1 ]] || die "pkg:install <pkgs...>"; run "sudo apt-get install $(ynflag) $*";;
    remove) need apt-get; [[ $# -ge 1 ]] || die "pkg:remove <pkgs...>"; run "sudo apt-get remove $(ynflag) $*";;
    search) need apt-cache; [[ $# -ge 1 ]] || die "pkg:search <pattern>"; apt-cache search "$1";;
    *) die "Unknown pkg subcommand";;
  esac
}

svc_router() {
  local sub="${1:-}"; shift || true
  case "$sub" in
    start|stop|restart|enable|disable) [[ $# -eq 1 ]] || die "svc:$sub <service>"; run "sudo systemctl $sub '$1'";;
    status) [[ $# -eq 1 ]] || die "svc:status <service>"; sudo systemctl status --no-pager "$1";;
    *) die "Unknown svc subcommand";;
  esac
}

sys_router() {
  local sub="${1:-}"; shift || true
  case "$sub" in
    uptime) uptime;;
    df) df -hT | (read -r h; echo "$h"; sort -hk6);;
    du) local path="${1:-/}"; du -xh --max-depth=1 "$path" 2>/dev/null | sort -hr | head -n 30;;
    mem) free -h;;
    topcpu) local n="${1:-10}"; ps -eo pid,ppid,cmd,%cpu,%mem --sort=-%cpu | head -n $((n+1));;
    topmem) local n="${1:-10}"; ps -eo pid,ppid,cmd,%cpu,%mem --sort=-%mem | head -n $((n+1));;
    temps) if command -v sensors &>/dev/null; then sensors; else echo "Install 'lm-sensors' for temps."; fi;;
    hw) echo "CPU:"; lscpu | sed -n '1,12p'; echo; echo "MEM:"; free -h; echo; echo "BLOCK:"; lsblk -o NAME,SIZE,TYPE,MOUNTPOINT | sed -n '1,20p';;
    *) die "Unknown sys subcommand";;
  esac
}

fs_router() {
  local sub="${1:-}"; shift || true
  case "$sub" in
    largest) local path="${1:-/}" n="${2:-20}"; sudo find "$path" -xdev -type f -printf '%s %p\n' 2>/dev/null | sort -nr | head -n "$n" | awk '{ printf "%10.2f MB  %s\n", $1/1024/1024, substr($0,index($0,$2)) }';;
    find) [[ $# -ge 2 ]] || die "fs:find <path> <name>"; sudo find "$1" -iname "*$2*";;
    grep) [[ $# -ge 2 ]] || die "fs:grep <path> <pattern>"; grep -Rin --color=always "$2" "$1";;
    perm:fix) [[ $# -ge 2 ]] || die "fs:perm:fix <path> <user>"; run "sudo chown -R ${2}:${2} '$1'"; run "sudo chmod -R u+rwX,go-rwx '$1'";;
    tar) [[ $# -eq 2 ]] || die "fs:tar <src> <dst.tar.gz>"; run "tar -czf '$2' -C \"$(dirname "$1")\" \"$(basename "$1")\"";;
    rsync) [[ $# -eq 2 ]] || die "fs:rsync <src> <dst>"; run "rsync -a --info=progress2 '$1' '$2'";;
    *) die "Unknown fs subcommand";;
  esac
}

net_router() {
  local sub="${1:-}"; shift || true
  case "$sub" in
    ip) ip -br addr || ifconfig; echo; echo "Gateways:"; ip route show default || true;;
    ports) if command -v ss &>/dev/null; then sudo ss -lntup; else sudo netstat -lntup; fi;;
    ping) [[ $# -eq 1 ]] || die "net:ping <host>"; ping -c 4 "$1";;
    dns) [[ $# -eq 1 ]] || die "net:dns <name>"; getent ahosts "$1" || dig +short "$1" || host "$1";;
    curl) [[ $# -eq 1 ]] || die "net:curl <url>"; curl -w "\n\nTime_namelookup: %{time_namelookup}\nTime_connect: %{time_connect}\nTime_starttransfer: %{time_starttransfer}\nTime_total: %{time_total}\n" -sSL -o /dev/null "$1";;
    ssh) [[ $# -eq 1 ]] || die "net:ssh <user@host>"; ssh -o StrictHostKeyChecking=accept-new -o ServerAliveInterval=30 "$1";;
    *) die "Unknown net subcommand";;
  esac
}

log_router() {
  local sub="${1:-}"; shift || true
  case "$sub" in
    sys) local n="${1:-200}"; sudo tail -n "$n" /var/log/syslog 2>/dev/null || sudo journalctl -n "$n" --no-pager;;
    j) [[ $# -ge 1 ]] || die "log:j <unit> [n]"; local unit="$1" n="${2:-200}"; sudo journalctl -u "$unit" -n "$n" --no-pager;;
    grep) [[ $# -eq 1 ]] || die "log:grep <pattern>"; sudo journalctl -xe --no-pager | grep -i --color=always "$1" || true;;
    *) die "Unknown log subcommand";;
  esac
}

fw_router() {
  need ufw
  local sub="${1:-}"; shift || true
  case "$sub" in
    status) sudo ufw status verbose;;
    allow) [[ $# -eq 1 ]] || die "fw:allow <port/proto>"; run "sudo ufw allow '$1'";;
    deny) [[ $# -eq 1 ]] || die "fw:deny <port/proto>"; run "sudo ufw deny '$1'";;
    enable) run "echo 'y' | sudo ufw enable";;
    disable) run "sudo ufw disable";;
    *) die "Unknown fw subcommand";;
  esac
}

dk_router() {
  need docker
  local sub="${1:-}"; shift || true
  case "$sub" in
    ps) docker ps --format 'table {{.Names}}\t{{.Image}}\t{{.Status}}\t{{.Ports}}';;
    logs) [[ $# -ge 1 ]] || die "dk:logs <name> [n]"; local n="${2:-200}"; docker logs --tail "$n" -f "$1";;
    exec) [[ $# -ge 2 ]] || die "dk:exec <name> <cmd...>"; docker exec -it "$1" "${@:2}";;
    stats) docker stats;;
    *) die "Unknown dk subcommand";;
  esac
}

git_router() {
  local sub="${1:-}"; shift || true
  local dir="${1:-$PWD}"
  case "$sub" in
    status) (cd "$dir" && git status -sb);;
    pull) (cd "$dir" && git pull --rebase --autostash);;
    sync) (cd "$dir" && git fetch --all --prune && git pull --ff-only || true);;
    *) die "Unknown git subcommand";;
  esac
}

cron_router() {
  local sub="${1:-}"; shift || true
  case "$sub" in
    list) crontab -l || true;;
    edit) crontab -e;;
    add) [[ $# -eq 1 ]] || die "cron:add \"<cron line>\""; (crontab -l 2>/dev/null; echo "$1") | crontab -; echo "[✔] Cron line added.";;
    *) die "Unknown cron subcommand";;
  esac
}

bkp_router() {
  local sub="${1:-}"; shift || true
  case "$sub" in
    quick)
      [[ $# -eq 2 ]] || die "bkp:quick <src> <dstdir>"
      local ts base dst
      ts="$(date +%Y%m%d-%H%M%S)"; base="$(basename "$1")"
      mkdir -p "$2"; dst="$2/${base}-${ts}.tar.gz"
      run "tar -czf '$dst' -C \"$(dirname "$1")\" \"$base\""
      echo "[✔] Backup: $dst"
      ;;
    rotate)
      [[ $# -eq 2 ]] || die "bkp:rotate <dir> <keepN>"
      local dir="$1" keep="$2"
      mapfile -t files < <(ls -1t "$dir"/*.tar.gz 2>/dev/null || true)
      (( ${#files[@]} <= keep )) && { echo "[i] Nothing to rotate."; exit 0; }
      for f in "${files[@]:$keep}"; do run "rm -f '$f'"; done
      echo "[✔] Rotation complete. Kept newest $keep."
      ;;
    *) die "Unknown bkp subcommand";;
  esac
}

# ── Menu / Help / Versions ───────────────────────────────────────────────────
show_menu() {
  echo -e "\n🧠 Omniscient Control Panel"
  echo "──────────────────────────"
  echo " 1) View system environment"
  echo " 2) Run AI summary process"
  echo " 3) Trigger scheduled maintenance"
  echo " 4) Start core services"
  echo " 5) Restart core services"
  echo " 6) Stop core services"
  echo " 7) Check service health"
  echo " 8) Show system status"
  echo " 9) Run plugins"
  echo "10) Explore script directories"
  echo "11) Show version info"
  echo "12) Help"
  echo "13) Exit"
  echo "──────────────────────────"
  read -rp "Enter selection: " choice
  case "$choice" in
    1) view_environment ;;
    2) run_summary ;;
    3) trigger_maintenance ;;
    4) start_services ;;
    5) restart_services ;;
    6) stop_services ;;
    7) health_check ;;
    8) show_status ;;
    9) run_plugins ;;
    10) browse_directories ;;
    11) show_versions ;|
    12) show_help ;|
    13) exit 0 ;;
    *) echo "Invalid option"; sleep 1 ;;
  esac
  show_menu
}

show_versions() {
  echo -e "\n🧐 OmniscientCTL Version: $OMNISCIENTCTL_VERSION"
  if command -v git &>/dev/null && git rev-parse --is-inside-work-tree &>/dev/null; then
    branch=$(git rev-parse --abbrev-ref HEAD)
    commit=$(git rev-parse --short HEAD)
    echo "🔖 Git: Branch [$branch], Commit [$commit]"
  fi
  echo "📂 Framework Modules:"
  for cmd in "${!MODULES[@]}"; do
    version_var="MOD_VERSION_${cmd}"
    version="${!version_var:-${MOD_VERSION:-unknown}}"
    echo "  $cmd : $version"
  done
}

show_help() {
cat <<'EOF'

🧠 Omniscient Framework CLI (omniscientctl)

Usage:
  omniscientctl <command> [args]

Core:
  help                       Show this help
  version                    Show loaded module versions
  menu                       Launch interactive menu (default with no args)
  prompt "<text>" [engine]   Send a prompt to Ollama/OpenAI/GPT4All

Framework lifecycle (example placeholders to wire later if desired):
  install | update | backup
  start | stop | restart     (controls omniscient.service)

Env Flags:
  DRY_RUN=1                  Log actions without executing
  ASSUME_YES=1               Auto-confirm (-y) where supported

Sysadmin wrappers:
  pkg:update                 apt update && upgrade
  pkg:install <pkgs...>      Install packages
  pkg:remove <pkgs...>       Remove packages
  pkg:search <pattern>       Search apt cache

  svc:start|stop|restart|enable|disable <name>
  svc:status <name>

  sys:uptime | df | du [path] | mem | topcpu [n] | topmem [n] | temps | hw
  fs:largest <path> [n] | fs:find <path> <name> | fs:grep <path> <pat>
  fs:perm:fix <path> <user> | fs:tar <src> <dst.tar.gz> | fs:rsync <src> <dst>
  net:ip | ports | ping <host> | dns <name> | curl <url> | ssh <user@host>
  log:sys [n] | log:j <unit> [n] | log:grep <pattern>
  fw:status|allow|deny|enable|disable (uses ufw)
  dk:ps | dk:logs <name> [n] | dk:exec <name> <cmd...> | dk:stats
  git:status [dir] | git:pull [dir] | git:sync [dir]
  cron:list | cron:edit | cron:add "<line>"
  bkp:quick <src> <dstdir> | bkp:rotate <dir> <keepN>

EOF
}

# ── CLI Entry Point / Router ─────────────────────────────────────────────────
if [[ $# -eq 0 ]]; then
  clear
  show_menu
  exit 0
fi

case "$1" in
  help|-h|--help) show_help ;;

  version|--version|-v) show_versions ;;

  menu) show_menu ;;

  prompt)
    [[ $# -ge 2 ]] || die 'Usage: prompt "<text>" [engine]'
    shift
    # support: prompt -f <file> [engine]
    if [[ "${1:-}" == "-f" ]]; then
      [[ -f "${2:-}" ]] || die "No such file: ${2:-}"
      prompt_text="$(cat "$2")"; engine="${3:-$MODEL}"
    else
      prompt_text="$1"; engine="${2:-$MODEL}"
    fi
    do_prompt "$prompt_text" "$engine"
    ;;

  # Namespaces (extract sub then pass args)
  pkg:*)  sub="${1#*:}"; shift; pkg_router "$sub" "$@";;
  svc:*)  sub="${1#*:}"; shift; svc_router "$sub" "$@";;
  sys:*)  sub="${1#*:}"; shift; sys_router "$sub" "$@";;
  fs:*)   sub="${1#*:}"; shift; fs_router  "$sub" "$@";;
  net:*)  sub="${1#*:}"; shift; net_router "$sub" "$@";;
  log:*)  sub="${1#*:}"; shift; log_router "$sub" "$@";;
  fw:*)   sub="${1#*:}"; shift; fw_router  "$sub" "$@";;
  dk:*)   sub="${1#*:}"; shift; dk_router  "$sub" "$@";;
  git:*)  sub="${1#*:}"; shift; git_router "$sub" "$@";;
  cron:*) sub="${1#*:}"; shift; cron_router "$sub" "$@";;
  bkp:*)  sub="${1#*:}"; shift; bkp_router "$sub" "$@";;

  # Module passthrough (mod_*.sh exposing functions)
  *)
    if [[ -n "${MODULES[${1}] :-}" ]]; then
      cmd="$1"; shift; "${MODULES[$cmd]}" "$@"
    else
      echo "[✘] Unknown command: $1"
      show_help
      exit 1
    fi
    ;;
esac
