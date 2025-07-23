#!/bin/bash

# ─── OMNISCIENT FRAMEWORK CLI ───────────────────────────────────────────────

# Version
OMNISCIENTCTL_VERSION="1.0.0"

# Auto-source environment
OMNIROOT="/opt/omniscient"
[ -f "$OMNIROOT/.env" ] && source "$OMNIROOT/.env"
source "$OMNIROOT/.autoenv/activate.sh"

SCRIPT_DIRS=("ai" "core" "bin" "menus" "modules" "malformed" "offensive" "system" "scripts" "osint" "logs")
OMNIDIR="$OMNIROOT/control/omniscientctl.d"
CONF="$OMNIROOT/omniscient.conf"
LOG="$OMNIROOT/logs/omniscientctl.log"
PROMPT_LOG="${PROMPT_LOG:-$OMNIROOT/logs/prompt.log}"

mkdir -p "$(dirname "$LOG")"
echo "[+] OmniscientCTL invoked at $(date) with args: $*" >> "$LOG"

# Load drop-in shell modules
for f in "$OMNIDIR"/*.bash; do [[ -f "$f" ]] && source "$f"; done

# Helper Functions
log_action() {
  echo "[$(date +'%F %T')] $1" | tee -a "$PROMPT_LOG"
}

restart_services() {
  log_action "Restarting core services: $SERVICES_TO_ENABLE"
  IFS=',' read -ra SERVICES <<< "$SERVICES_TO_ENABLE"
  for service in "${SERVICES[@]}"; do
    echo "Restarting $service..."
    sudo systemctl restart "$service"
  done
  show_menu
}

stop_services() {
  log_action "Stopping core services: $SERVICES_TO_ENABLE"
  IFS=',' read -ra SERVICES <<< "$SERVICES_TO_ENABLE"
  for service in "${SERVICES[@]}"; do
    echo "Stopping $service..."
    sudo systemctl stop "$service"
  done
  show_menu
}

health_check() {
  log_action "Checking health of core services"
  IFS=',' read -ra SERVICES <<< "$SERVICES_TO_ENABLE"
  for service in "${SERVICES[@]}"; do
    STATUS=$(systemctl is-active "$service")
    echo "$service → $STATUS"
  done
  show_menu
}

run_plugins() {
  local plugin_dir="${OMNISCIENT_PLUGIN_DIR:-$OMNIROOT/plugins}"
  echo -e "\n🗉 Executing plugins in $plugin_dir"
  for plugin in "$plugin_dir"/*.sh; do
    [ -x "$plugin" ] && echo "→ Running $(basename "$plugin")" && bash "$plugin"
  done
  show_menu
}

browse_directories() {
  echo -e "\n📂 Available Script Categories:"
  select dir in "${SCRIPT_DIRS[@]}" "Back"; do
    [[ "$REPLY" == $(( ${#SCRIPT_DIRS[@]} + 1 )) ]] && show_menu && return
    TARGET="$OMNIROOT/$dir"
    if [[ -d "$TARGET" ]]; then
      echo -e "\n📁 $dir Directory Contents:"
      mapfile -t files < <(find "$TARGET" -maxdepth 1 -type f \( -name "*.sh" -o -name "*.bash" \))
      select file in "${files[@]}" "Back"; do
        [[ "$REPLY" == $(( ${#files[@]} + 1 )) ]] && browse_directories && return
        [[ -f "$file" ]] && echo -e "\n🚀 Executing: $file\n" && log_action "Executing user script: $file" && bash "$file" && break
        echo "Invalid selection. Try again."
      done
    else
      echo "[\u2718] Directory not found: $TARGET"
    fi
    break
  done
}

# Load config values
if command -v crudini &> /dev/null && [[ -f "$CONF" ]]; then
  MODEL=$(crudini --get "$CONF" models MODEL_BACKEND 2>/dev/null || echo "gpt4all")
  LOG_LEVEL=$(crudini --get "$CONF" core LOG_LEVEL 2>/dev/null || echo "INFO")
  OLLAMA_API=$(crudini --get "$CONF" ollama API_URL 2>/dev/null || echo "http://localhost:11434/api/generate")
else
  MODEL="gpt4all"; LOG_LEVEL="INFO"; OLLAMA_API="http://localhost:11434/api/generate"
fi

# Activate Python virtual environment
if [[ -z "$VIRTUAL_ENV" ]]; then
  for path in "$OMNIROOT/venv/bin/activate" "$OMNIROOT/bin/activate" "$OMNIROOT/.env/bin/activate"; do
    [[ -f "$path" ]] && source "$path" && break
  done
fi

# Auto-register modules
MODULE_DIR="$OMNIROOT/modules"
declare -A MODULES=()

if [[ -d "$MODULE_DIR" ]]; then
  for mod_file in "$MODULE_DIR"/mod_*.sh; do
    [[ -f "$mod_file" ]] || continue
    mod_basename=$(basename "$mod_file" .sh)
    mod_name=${mod_basename#mod_}
    enabled="true"
    if command -v crudini &> /dev/null && [[ -f "$CONF" ]]; then
      enabled=$(crudini --get "$CONF" modules "$mod_name" 2>/dev/null || echo "true")
    fi
    if [[ "$enabled" == "true" ]]; then
      source "$mod_file"
      MODULES["$mod_name"]="mod_${mod_name}"
    fi
  done
fi

# Menu Functions
show_menu() {
  echo -e "\n🧠 Omniscient Control Panel"
  echo "──────────────────────────"
  echo "1) View system environment"
  echo "2) Run AI summary process"
  echo "3) Trigger scheduled maintenance"
  echo "4) Start core services"
  echo "5) Restart core services"
  echo "6) Stop core services"
  echo "7) Check service health"
  echo "8) Show system status"
  echo "9) Run plugins"
  echo "10) Explore script directories"
  echo "11) Show version info"
  echo "12) Exit"
  echo "──────────────────────────"
  read -p "Enter selection: " choice
  case $choice in
    1) view_environment;;
    2) run_summary;;
    3) trigger_maintenance;;
    4) start_services;;
    5) restart_services;;
    6) stop_services;;
    7) health_check;;
    8) show_status;;
    9) run_plugins;;
    10) browse_directories;;
    11) show_versions;;
    12) exit 0;;
    *) echo "Invalid option"; sleep 1; show_menu;;
  esac
}

show_versions() {
  echo "\n🧐 OmniscientCTL Version: $OMNISCIENTCTL_VERSION"
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
  show_menu
}

# Placeholder function stubs for completeness
view_environment() {
  log_action "Displaying Omniscient environment"
  env | grep -E 'OMNISCIENT_|SUMMARY_LOG|PROMPT_LOG|DEFAULT_MODEL|OLLAMA_API|IP_ADDRESS|GATEWAY|DNS_SERVERS'
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

start_services() {
  log_action "Starting core services: $SERVICES_TO_ENABLE"
  IFS=',' read -ra SERVICES <<< "$SERVICES_TO_ENABLE"
  for service in "${SERVICES[@]}"; do
    echo "Starting $service..."
    sudo systemctl start "$service"
  done
  show_menu
}

show_status() {
  log_action "Gathering system status info"
  echo "Uptime: $(uptime -p)"
  echo "IP: $(hostname -I | awk '{print $1}')"
  echo "Disk:"; df -h | grep -E '/$|/opt|/var'
  echo "Memory:"; free -h | grep -v Swap
  show_menu
}

# CLI Entry Point
if [[ -z "$1" ]]; then
  clear
  show_menu
  exit 0
fi

case "$1" in
  version|--version|-v) show_versions; exit 0 ;;
  *) echo "[✘] Unknown command: $1"; show_menu; exit 1 ;;
esac
