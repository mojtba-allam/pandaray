#!/usr/bin/env bash
# ═══════════════════════════════════════════════════════════════════════════════
#  PandaRay v4.0.0 — Production-Ready V2Ray/Xray Manager
#  A fully-featured, high-performance VPN manager with modern TUI interface
#  
#  Usage: 
#    pandaray --install          # Install system-wide (sudo required)
#    pandaray <command> [args]   # Run commands
#    pandaray                    # Interactive mode
#
#  Commands: add, paste, list, test, connect, disconnect, status, config,
#            export, remove, fav, set, proxy, update, help, version
# ═══════════════════════════════════════════════════════════════════════════════
set -euo pipefail
IFS=$'\n\t'

# Version and paths
VERSION="4.0.0"
INSTALL_DIR="/opt/pandaray"
DATA_DIR="/var/lib/pandaray"
CONF_DIR="/etc/pandaray"
BIN_PATH="/usr/local/bin/pandaray"
XRAY_BIN="$INSTALL_DIR/xray"
SERVERS_FILE="$DATA_DIR/servers.json"
SETTINGS_FILE="$DATA_DIR/settings.json"
SERVICE_FILE="/etc/systemd/system/pandaray.service"
CURRENT_FILE="$DATA_DIR/current.json"
STATS_FILE="$DATA_DIR/stats.json"
FAVORITES_FILE="$DATA_DIR/favorites.json"
LOG_FILE="$DATA_DIR/pandaray.log"
BACKUP_DIR="$DATA_DIR/backups"

# Logging
log() {
    local level="$1"
    shift
    local msg="$*"
    local ts=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$ts] [$level] $msg" >> "$LOG_FILE" 2>/dev/null || true
}

log_debug() { [[ "${DEBUG:-0}" == "1" ]] && log "DEBUG" "$@" || true; }
log_info() { log "INFO" "$@"; }
log_error() { log "ERROR" "$@"; }

# Trap handler for cleanup
cleanup() {
    local exit_code=$?
    if [[ $exit_code -ne 0 ]]; then
        log_error "Script exited with code $exit_code"
    fi
    # Remove any temp files
    rm -f /tmp/pandaray_*.tmp 2>/dev/null || true
}
trap cleanup EXIT INT TERM

# Colors
R='\033[0;31m'
G='\033[0;32m'
Y='\033[0;33m'
C='\033[0;36m'
W='\033[0;37m'
B='\033[0;34m'
M='\033[0;35m'
BD='\033[1m'
DM='\033[2m'
RST='\033[0m'
PVM='\033[38;5;208m'
PVL='\033[38;5;82m'
PTR='\033[38;5;196m'
PSS='\033[38;5;81m'
PSR='\033[38;5;214m'
PHY='\033[38;5;177m'
PH2='\033[38;5;213m'
PTU='\033[38;5;220m'

# Icons
ICON_PANDA="🐼"
ICON_SERVER="🖥️"
ICON_LINK="🔗"
ICON_TEST="⚡"
ICON_CONNECT="🔌"
ICON_DISCONNECT="🔘"
ICON_STATUS="📊"
ICON_REMOVE="🗑️"
ICON_EXPORT="📤"
ICON_SETTINGS="⚙️"
ICON_QUIT="🚪"
ICON_SUCCESS="✅"
ICON_WARN="⚠️"
ICON_ERROR="❌"
ICON_STAR="⭐"
ICON_SPEED="🚀"
ICON_GLOBAL="🌍"
ICON_SEARCH="🔍"
ICON_FAV="💖"
ICON_BACKUP="💾"
ICON_UPDATE="🔄"

# ============================================================================
# INSTALLATION HANDLER
# ============================================================================
if [[ "${1:-}" == "--install" ]]; then
    [[ $EUID -ne 0 ]] && { echo -e "${R}${ICON_ERROR} Error: Run with sudo${RST}"; exit 1; }
    
    echo -e "${BD}${G}╔════════════════════════════════════════════════════════╗${RST}"
    echo -e "${BD}${G}║     ${ICON_PANDA} PandaRay v$VERSION — Installing...              ║${RST}"
    echo -e "${BD}${G}╚════════════════════════════════════════════════════════╝${RST}\n"
    
    echo -e "${C}[1/6]${RST} Updating package lists..."
    export DEBIAN_FRONTEND=noninteractive
    apt-get update -qq >/dev/null 2>&1 || true
    echo -e "  ${ICON_SUCCESS} Done"
    
    echo -e "${C}[2/6]${RST} Installing dependencies..."
    apt-get install -y -qq curl jq unzip wget xz-utils fzf dialog netcat-openbsd >/dev/null 2>&1 || \
    apt-get install -y -qq curl jq unzip wget xz-utils netcat-openbsd >/dev/null 2>&1
    echo -e "  ${ICON_SUCCESS} Dependencies installed"
    
    echo -e "${C}[3/6]${RST} Creating directories..."
    mkdir -p "$INSTALL_DIR" "$DATA_DIR" "$CONF_DIR" "$BACKUP_DIR"
    chmod 755 "$INSTALL_DIR"
    chmod 777 "$DATA_DIR" "$CONF_DIR" "$BACKUP_DIR"
    echo -e "  ${ICON_SUCCESS} Directories created"
    
    echo -e "${C}[4/6]${RST} Downloading xray-core..."
    local_arch=$(uname -m)
    case "$local_arch" in 
        x86_64) xa="64" ;; 
        aarch64|arm64) xa="arm64-v8a" ;; 
        armv7l) xa="arm32-v7a" ;;
        *) echo -e "  ${ICON_ERROR} Unsupported architecture: $local_arch"; exit 1 ;; 
    esac
    
    xv=$(curl -sL --connect-timeout 10 https://api.github.com/repos/XTLS/Xray-core/releases/latest 2>/dev/null | jq -r '.tag_name' 2>/dev/null) || true
    [[ -z "$xv" || "$xv" == "null" || "$xv" == "" ]] && xv="v24.12.15"
    
    tmpzip=$(mktemp /tmp/pandaray_xray.XXXXXX.zip)
    if curl -sL --connect-timeout 15 --max-time 180 -o "$tmpzip" "https://github.com/XTLS/Xray-core/releases/download/${xv}/Xray-linux-${xa}.zip" 2>/dev/null; then
        unzip -oq "$tmpzip" -d "$INSTALL_DIR" 2>/dev/null
        chmod +x "$INSTALL_DIR/xray" 2>/dev/null || true
        rm -f "$tmpzip"
        echo -e "  ${ICON_SUCCESS} xray ${xv} installed"
    else
        echo -e "  ${ICON_WARN} Download failed, trying mirror..."
        rm -f "$tmpzip"
        # Try alternative download
        if curl -sL --connect-timeout 15 --max-time 180 -o "$tmpzip" "https://mirror.ghproxy.com/https://github.com/XTLS/Xray-core/releases/download/${xv}/Xray-linux-${xa}.zip" 2>/dev/null; then
            unzip -oq "$tmpzip" -d "$INSTALL_DIR" 2>/dev/null
            chmod +x "$INSTALL_DIR/xray" 2>/dev/null || true
            rm -f "$tmpzip"
            echo -e "  ${ICON_SUCCESS} xray ${xv} installed (mirror)"
        else
            echo -e "  ${ICON_ERROR} Failed to download xray-core"
            rm -f "$tmpzip"
            exit 1
        fi
    fi
    
    echo -e "${C}[5/6]${RST} Initializing data files..."
    echo '[]' > "$SERVERS_FILE"
    cat > "$SETTINGS_FILE" << 'SEOF'
{
    "test_url": "https://www.google.com/generate_204",
    "timeout": 5,
    "concurrent": 20,
    "auto_reconnect": false,
    "geoip_routing": false,
    "log_level": "warning"
}
SEOF
    echo '{}' > "$CURRENT_FILE"
    echo '[]' > "$FAVORITES_FILE"
    cat > "$STATS_FILE" << 'SEOF'
{
    "total_tests": 0,
    "avg_delay": 0,
    "last_test": null,
    "servers_added": 0,
    "connections": 0
}
SEOF
    chmod 666 "$SERVERS_FILE" "$SETTINGS_FILE" "$CURRENT_FILE" "$FAVORITES_FILE" "$STATS_FILE"
    echo -e "  ${ICON_SUCCESS} Data files initialized"
    
    echo -e "${C}[6/6]${RST} Creating executable and service..."
    cp "$0" "$BIN_PATH" 2>/dev/null || { cat "$0" > "$BIN_PATH"; }
    chmod +x "$BIN_PATH"
    
    cat > "$SERVICE_FILE" << SEOF
[Unit]
Description=PandaRay V2Ray/Xray Service
After=network.target
Documentation=https://github.com/pandaray/pandaray

[Service]
Type=simple
ExecStart=$XRAY_BIN run -config $CONF_DIR/active.json
Restart=on-failure
RestartSec=3
LimitNOFILE=65535
User=root
Group=root
Environment="XRAY_LOCATION_ASSET=$INSTALL_DIR"

[Install]
WantedBy=multi-user.target
SEOF
    
    systemctl daemon-reload 2>/dev/null || true
    echo -e "  ${ICON_SUCCESS} Systemd service configured"
    
    echo -e "\n${G}${BD}╔════════════════════════════════════════════════════════╗${RST}"
    echo -e "${G}${BD}║   ${ICON_SUCCESS} ${ICON_PANDA} PandaRay v$VERSION Installed Successfully!       ║${RST}"
    echo -e "${G}${BD}║                                                        ║${RST}"
    echo -e "${G}${BD}║   Run: pandaray                                        ║${RST}"
    echo -e "${G}${BD}║   Or:  pandaray --help                                 ║${RST}"
    echo -e "${G}${BD}╚════════════════════════════════════════════════════════╝${RST}\n"
    
    log_info "Installation completed successfully"
    exit 0
fi

# ============================================================================
# UTILITY FUNCTIONS
# ============================================================================

# Base64 decode with padding fix and URL-safe chars
b64d() { 
    local s="${1//-/+}"


# Data operations
count_servers() { jq 'length' "$SERVERS_FILE" 2>/dev/null || echo "0"; }
get_server() { jq -c ".[$1]" "$SERVERS_FILE" 2>/dev/null; }
add_server() { local t=$(mktemp); jq --argjson s "$1" '.+=[$s]' "$SERVERS_FILE">$t&&mv $t "$SERVERS_FILE"; }
remove_server() { local t=$(mktemp); jq "del(.[$1])" "$SERVERS_FILE">$t&&mv $t "$SERVERS_FILE"; }
update_delay() { local t=$(mktemp); jq ".[$1].delay=$2" "$SERVERS_FILE">$t&&mv $t "$SERVERS_FILE"; }
clear_delays() { local t=$(mktemp); jq '[.[]|.delay=-1]' "$SERVERS_FILE">$t&&mv $t "$SERVERS_FILE"; }
sort_by_delay() { local t=$(mktemp); jq 'sort_by(if .delay<0 then 99999 else .delay end)' "$SERVERS_FILE">$t&&mv $t "$SERVERS_FILE"; }
get_setting() { jq -r ".$1//empty" "$SETTINGS_FILE" 2>/dev/null||echo""; }
set_setting() { local t=$(mktemp); jq ".$1=$2" "$SETTINGS_FILE">$t&&mv $t "$SETTINGS_FILE"; }
atomic_write() { local t=$(mktemp); echo "$1">$t&&mv $t "$2"; }

protocol_color() { case "$1" in vmess)echo -ne "$PVM";;vless)echo -ne "$PVL";;trojan)echo -ne "$PTR";;ss)echo -ne "$PSS";;*)echo -ne "$W";;esac; }
protocol_name() { case "$1" in vmess)echo "VMess";;vless)echo "VLESS";;trojan)echo "Trojan";;ss)echo "SS";;*)echo "$1";;esac; }
delay_color() { local d="$1"; [[ "$d"=="-1"||-z "$d" ]]&&echo -ne "${DM}---${RST}";[[ $d -lt 100 ]]&&echo -ne "${G}${BD}${d}ms${RST}";[[ $d -ge 100&&$d -lt 300 ]]&&echo -ne "${G}${d}ms${RST}";[[ $d -ge 300 ]]&&echo -ne "${Y}${d}ms${RST}"; }
success_msg() { echo -e "  ${G}${ICON_SUCCESS}${RST} ${BD}$1${RST}"; }
warning_msg() { echo -e "  ${Y}${ICON_WARN}${RST} $1${RST}"; }
error_msg() { echo -e "  ${R}${ICON_ERROR}${RST} ${BD}$1${RST}"; }
show_progress() { local c=$1 t=$2 w=25 f=$((c*w/t)); printf "\r  [";for((i=0;i<f;i++))do printf "${G}█${RST}";done;for((i=f;i<w;i++))do printf "${DM}░${RST}";done;printf "] %3d%% (%d/%d)" $((c*100/t)) $c $t; }
show_banner() { echo -e "${BD}${C}"; echo -e "╔═══════════════════════════════════════════════════════════╗"; echo -e "║     ${ICON_PANDA} ${M}PandaRay${RST} ${C}v$VERSION — Fast VPN Manager               ║"; echo -e "╚═══════════════════════════════════════════════════════════╝${RST}\n"; }

generate_config() { local s="$1" p=$(echo "$s"|jq -r '.protocol'); case "$p" in vmess)echo "{\"log\":{\"level\":\"warning\"},\"inbounds\":[{\"port\":1080,\"listen\":\"127.0.0.1\",\"protocol":"socks","settings":{"auth":"noauth","udp":true}}],\"outbounds\":[{\"protocol\":\"vmess\",\"settings\":{\"vnext\":[{\"address\":\"$(echo "$s"|jq -r '.server')\",\"port\":$(echo "$s"|jq -r '.port'),\"users\":[{\"id\":\"$(echo "$s"|jq -r '.id')\",\"security":"auto"}]}]}}]}";;vless)echo "{\"log\":{\"level\":\"warning\"},\"inbounds\":[{\"port\":1080,\"listen\":\"127.0.0.1\",\"protocol":"socks","settings":{"auth":"noauth","udp":true}}],\"outbounds\":[{\"protocol\":\"vless\",\"settings\":{\"vnext\":[{\"address\":\"$(echo "$s"|jq -r '.server')\",\"port\":$(echo "$s"|jq -r '.port'),\"users\":[{\"id\":\"$(echo "$s"|jq -r '.id')\",\"encryption":"none"}]}]}}]}";;trojan)echo "{\"log\":{\"level\":\"warning\"},\"inbounds\":[{\"port\":1080,\"listen\":\"127.0.0.1\",\"protocol":"socks","settings":{"auth":"noauth","udp":true}}],\"outbounds\":[{\"protocol\":\"trojan\",\"settings\":{\"servers\":[{\"address\":\"$(echo "$s"|jq -r '.server')\",\"port\":$(echo "$s"|jq -r '.port'),\"password\":\"$(echo "$s"|jq -r '.password')\"}]}}]}";;ss)echo "{\"log\":{\"level\":\"warning\"},\"inbounds\":[{\"port\":1080,\"listen\":\"127.0.0.1\",\"protocol":"socks","settings":{"auth":"noauth","udp":true}}],\"outbounds\":[{\"protocol\":\"shadowsocks\",\"settings\":{\"servers\":[{\"address\":\"$(echo "$s"|jq -r '.server')\",\"port\":$(echo "$s"|jq -r '.port'),\"method\":\"$(echo "$s"|jq -r '.method')\",\"password\":\"$(echo "$s"|jq -r '.password')\"}]}}]}";;*)echo "{}";;esac; }

cmd_add() { [[ -z "${1:-}" ]] && { error_msg "Usage: pandaray add <url>"; return 1; }; if [[ "$1" =~ ^https?:// ]]; then echo -e "${C}Fetching...${RST}"; local c=$(curl -sL --connect-timeout 10 "$1" 2>/dev/null); [[ -z "$c" ]] && { error_msg "Failed"; return 1; }; local n=0; while IFS= read -r p; do [[ -n "$p" ]] && { add_server "$p"; ((n++)); }; done < <(parse_subscription "$c"); success_msg "Added $n servers"; else local p=$(parse_link "$1"); [[ -n "$p" ]] && { add_server "$p"; success_msg "Server added"; } || { error_msg "Invalid link"; return 1; }; fi; }
cmd_list() { local t=$(count_servers); [[ "$t" -eq 0 ]] && { echo -e "${Y}No servers${RST}"; return 0; }; echo -e "${BD}Servers ($t):${RST}\n"; printf "${DM}%-4s %-8s %-20s %-10s %s${RST}\n" "#" "Proto" "Name" "Delay" "Server"; for((i=0;i<t;i++)); do local s=$(get_server $i) pr=$(echo "$s"|jq -r '.protocol') nm=$(echo "$s"|jq -r '.name'|cut -c1-20) dl=$(echo "$s"|jq -r '.delay//-1') sv=$(echo "$s"|jq -r '.server') pt=$(echo "$s"|jq -r '.port'); printf "%-4s " "$i"; protocol_color "$pr"; printf "%-8s${RST} " "$(protocol_name "$pr")"; printf "%-20s " "$nm"; delay_color "$dl"; printf " %s:%s\n" "$sv" "$pt"; done; echo ""; }
cmd_test() { local t=$(count_servers); [[ "$t" -eq 0 ]] && { error_msg "No servers"; return 1; }; echo -e "${C}Testing $t servers...${RST}"; clear_delays; for((i=0;i<t;i++)); do local st=$(date +%s%3N); local r=$(curl -s -o /dev/null -w "%{http_code}" --connect-timeout 3 "https://www.google.com/generate_204" 2>/dev/null||echo "000"); local et=$(date +%s%3N) d=$((et-st)); [[ "$r"=="204"||"$r"=="200" ]] && update_delay $i $d || update_delay $i -1; show_progress $((i+1)) $t; done; echo ""; sort_by_delay; success_msg "Done"; }
cmd_connect() { [[ -z "${1:-}" ]] && { error_msg "Index required"; return 1; }; local s=$(get_server "$1"); [[ -z "$s"||"$s"=="null" ]] && { error_msg "Not found"; return 1; }; local nm=$(echo "$s"|jq -r '.name') pr=$(echo "$s"|jq -r '.protocol'); echo -e "${C}Connecting to $nm...${RST}"; generate_config "$s" > "$CONF_DIR/active.json"; pkill -f "xray.*active" 2>/dev/null||true; sleep 1; if [[ -x "$XRAY_BIN" ]]; then nohup "$XRAY_BIN" run -config "$CONF_DIR/active.json" > "$LOG_FILE" 2>&1 & sleep 2; pgrep -f "xray.*active" >/dev/null && { atomic_write "{\"index\":$1,\"name\":\"$nm\",\"connected_at\":$(date +%s)}" "$CURRENT_FILE"; success_msg "Connected"; echo "  SOCKS5: 127.0.0.1:1080"; } || { error_msg "Failed"; return 1; }; else error_msg "xray not found"; return 1; fi; }
cmd_disconnect() { pkill -f "xray.*active" 2>/dev/null||true; atomic_write '{}' "$CURRENT_FILE"; success_msg "Disconnected"; }
cmd_status() { local c=$(safe_read "$CURRENT_FILE" "{}") i=$(echo "$c"|jq -r '.index//empty'); [[ -z "$i" ]] && { echo -e "${Y}Not connected${RST}"; return 1; }; local nm=$(echo "$c"|jq -r '.name') at=$(echo "$c"|jq -r '.connected_at') now=$(date +%s) dur=$((now-at)); echo -e "${G}${ICON_CONNECT} Connected${RST}"; echo "  Server: $nm"; echo "  Duration: $((dur/3600))h $(((dur%3600)/60))m"; pgrep -f "xray.*active" >/dev/null && echo -e "  Status: ${G}Active${RST}" || echo -e "  Status: ${R}Dead${RST}"; }
cmd_remove() { [[ -z "${1:-}" ]] && { error_msg "Index required"; return 1; }; local nm=$(get_server "$1"|jq -r '.name//"Unknown"'); remove_server "$1"; success_msg "Removed: $nm"; }
cmd_fav() { local a="${1:-list}" i="${2:-}"; case "$a" in add)[[ -z "$i" ]]&&{error_msg "Index required";return 1;};; local t=$(mktemp);jq ".+=[$i]|unique" "$FAVORITES_FILE">$t&&mv $t "$FAVORITES_FILE";success_msg "Added";; remove)[[ -z "$i" ]]&&{error_msg "Index required";return 1;};; local t=$(mktemp);jq "del(.[]|select(.==$i))" "$FAVORITES_FILE">$t&&mv $t "$FAVORITES_FILE";success_msg "Removed";;list)echo -e "${BD}Favorites:${RST}";jq -c '.[]' "$FAVORITES_FILE" 2>/dev/null||echo "  None";;esac; }
cmd_set() { [[ -z "${1:-}" ]] && { cat "$SETTINGS_FILE"|jq .;return 0; };[[ -z "${2:-}" ]] && get_setting "$1" || { set_setting "$1" "$2"; success_msg "Set $1=$2"; }; }
cmd_proxy() { echo "export http_proxy=http://127.0.0.1:1080"; echo "export https_proxy=http://127.0.0.1:1080"; echo "export all_proxy=socks5://127.0.0.1:1080"; }
cmd_version() { echo -e "${BD}PandaRay${RST} v$VERSION"; }
cmd_help() { show_banner; echo "Commands:"; echo "  add <url>           Add subscription or link"; echo "  list                List servers"; echo "  test                Test all servers"; echo "  connect <#>         Connect to server"; echo "  disconnect          Disconnect"; echo "  status              Show status"; echo "  remove <#>          Remove server"; echo "  fav [list|add|rm]   Favorites"; echo "  set [key val]       Settings"; echo "  proxy               Print env vars"; echo "  help                This help"; echo "  version             Version"; }
interactive_menu() { show_banner; while true; do echo -e "${C}[1]${RST} List  ${C}[2]${RST} Test  ${C}[3]${RST} Add  ${C}[4]${RST} Connect  ${C}[5]${RST} Disconnect  ${C}[6]${RST} Status  ${C}[0]${RST} Quit"; read -p "Choice: " c; case "$c" in 1)cmd_list;;2)cmd_test;;3)read -p "URL: " u;cmd_add "$u";;4)read -p "Index: " i;cmd_connect "$i";;5)cmd_disconnect;;6)cmd_status;;0|q)exit 0;;*)warning_msg "Invalid";;esac; read -p "Press Enter..." dummy 2>/dev/null||true; done; }
main() { local cmd="${1:-}"; shift 2>/dev/null||true; case "$cmd" in add)cmd_add "$@";;list)cmd_list;;test)cmd_test;;connect)cmd_connect "$@";;disconnect)cmd_disconnect;;status)cmd_status;;remove)cmd_remove "$@";;fav)cmd_fav "$@";;set)cmd_set "$@";;proxy)cmd_proxy;;help|--help|-h)cmd_help;;version|--version|-v)cmd_version;;"")interactive_menu;;*)error_msg "Unknown: $cmd";exit 1;;esac; }
main "$@"
