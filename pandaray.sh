#!/usr/bin/env bash
# ═══════════════════════════════════════════════════════════
#  PandaRay v3.0.0 — Next-Gen V2Ray Manager for Ubuntu
#  Install: sudo bash pandaray.sh --install
#  Features: Modern UI, Fast Testing, Multi-Protocol Support
# ═══════════════════════════════════════════════════════════
set -eo pipefail

VERSION="3.0.0"
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

# Colors
R='\033[0;31m'
G='\033[0;32m'
Y='\033[0;33m'
C='\033[0;36m'
W='\033[0;37m'
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
GRAD1='\033[38;5;75m'

# Icons
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

# Installation Handler
if [[ "${1:-}" == "--install" ]]; then
    [[ $EUID -ne 0 ]] && { echo -e "${R}Error: Run with sudo${RST}"; exit 1; }
    echo -e "${BD}${G}Installing PandaRay v$VERSION...${RST}\n"
    
    echo -e "  ${C}[1/5]${RST} Installing dependencies..."
    export DEBIAN_FRONTEND=noninteractive
    apt-get update -qq && apt-get install -y -qq curl jq unzip systemd xz-utils >/dev/null 2>&1
    echo -e "  ${ICON_SUCCESS} Done"
    
    echo -e "  ${C}[2/5]${RST} Creating directories..."
    mkdir -p "$INSTALL_DIR" "$DATA_DIR" "$CONF_DIR"
    chmod 777 "$DATA_DIR" "$CONF_DIR"
    echo -e "  ${ICON_SUCCESS} Done"
    
    echo -e "  ${C}[3/5]${RST} Downloading xray-core..."
    local_arch=$(uname -m)
    case "$local_arch" in 
        x86_64) xa="64" ;; 
        aarch64) xa="arm64-v8a" ;; 
        *) echo -e "  ${ICON_ERROR} Unsupported arch"; exit 1 ;; 
    esac
    
    xv=$(curl -sL https://api.github.com/repos/XTLS/Xray-core/releases/latest | jq -r '.tag_name')
    [[ -z "$xv" || "$xv" == "null" ]] && xv="v24.12.15"
    
    tz=$(mktemp)
    if curl -sL --connect-timeout 15 --max-time 120 -o "$tz" "https://github.com/XTLS/Xray-core/releases/download/${xv}/Xray-linux-${xa}.zip"; then
        unzip -oq "$tz" -d "$INSTALL_DIR" 2>/dev/null
        chmod +x "$INSTALL_DIR/xray"
        rm -f "$tz"
        echo -e "  ${ICON_SUCCESS} xray ${xv}"
    else
        echo -e "  ${ICON_ERROR} Download failed"
        rm -f "$tz"
        exit 1
    fi
    
    echo -e "  ${C}[4/5]${RST} Initializing data files..."
    echo '[]' > "$SERVERS_FILE"
    echo '{"test_url":"https://www.google.com/generate_204","timeout":5,"concurrent":15}' > "$SETTINGS_FILE"
    echo '{}' > "$CURRENT_FILE"
    echo '[]' > "$FAVORITES_FILE"
    echo '{"total_tests":0,"avg_delay":0}' > "$STATS_FILE"
    chmod 666 "$SERVERS_FILE" "$SETTINGS_FILE" "$CURRENT_FILE" "$FAVORITES_FILE" "$STATS_FILE"
    echo -e "  ${ICON_SUCCESS} Done"
    
    echo -e "  ${C}[5/5]${RST} Creating executable..."
    cp "$0" "$BIN_PATH"
    chmod +x "$BIN_PATH"
    echo -e "  ${ICON_SUCCESS} Done"
    
    cat > "$SERVICE_FILE" << SEOF
[Unit]
Description=PandaRay V2Ray Service
After=network.target

[Service]
Type=simple
ExecStart=$XRAY_BIN run -config $CONF_DIR/active.json
Restart=on-failure
RestartSec=3
LimitNOFILE=65535

[Install]
WantedBy=multi-user.target
SEOF
    
    systemctl daemon-reload
    echo -e "  ${ICON_SUCCESS} Service configured"
    
    echo -e "\n${G}${BD}╔════════════════════════════════════════╗${RST}"
    echo -e "${G}${BD}║   ${ICON_SUCCESS} PandaRay v$VERSION Installed Successfully  ║${RST}"
    echo -e "${G}${BD}╚════════════════════════════════════════╝${RST}\n"
    exit 0
fi

# Base64 decode with padding fix
b64d() { 
    local s="${1//-/+}"
    s="${s//_/\/}"
    local m=$(( ${#s}%4 ))
    [[ $m -eq 2 ]] && s="${s}=="
    [[ $m -eq 3 ]] && s="${s}="
    echo "$s" | base64 -d 2>/dev/null || true
}

# URL decode
urid() { printf '%b' "${1//%/\\x}"; }

# Protocol color mapping
pcol() { 
    case "$1" in 
        vmess) echo -ne "$PVM" ;;
        vless) echo -ne "$PVL" ;;
        trojan) echo -ne "$PTR" ;;
        ss) echo -ne "$PSS" ;;
        ssr) echo -ne "$PSR" ;;
        hysteria) echo -ne "$PHY" ;;
        hy2) echo -ne "$PH2" ;;
        tuic) echo -ne "$PTU" ;;
        *) echo -ne "$W" ;;
    esac
}

# Protocol name mapping
pnam() { 
    case "$1" in 
        vmess) echo "VMess" ;;
        vless) echo "VLESS" ;;
        trojan) echo "Trojan" ;;
        ss) echo "SS" ;;
        ssr) echo "SSR" ;;
        hysteria) echo "Hy1" ;;
        hy2) echo "Hy2" ;;
        tuic) echo "TUIC" ;;
        *) echo "$1" ;;
    esac
}

# Delay color coding
dcol() { 
    local d="$1"
    if [[ "$d" -lt 0 ]]; then
        echo -ne "${DM}---${RST}"
    elif [[ "$d" -lt 100 ]]; then
        echo -ne "${G}${BD}${d}ms${RST} ${ICON_SPEED}"
    elif [[ "$d" -lt 200 ]]; then
        echo -ne "${G}${d}ms${RST}"
    elif [[ "$d" -lt 400 ]]; then
        echo -ne "${Y}${d}ms${RST}"
    else
        echo -ne "${R}${d}ms${RST}"
    fi
}

# Settings get/set
gs() { jq -r ".$1 // empty" "$SETTINGS_FILE" 2>/dev/null || echo ""; }
ss() { local t=$(mktemp); jq ".$1 = $2" "$SETTINGS_FILE" > "$t" && mv "$t" "$SETTINGS_FILE"; }

# Server operations
cs() { jq 'length' "$SERVERS_FILE" 2>/dev/null || echo "0"; }
gj() { jq -c ".[$1]" "$SERVERS_FILE" 2>/dev/null; }
as() { local t=$(mktemp); jq ". += [$1]" "$SERVERS_FILE" > "$t" && mv "$t" "$SERVERS_FILE"; }
rs() { local t=$(mktemp); jq "del(.[$1])" "$SERVERS_FILE" > "$t" && mv "$t" "$SERVERS_FILE"; }
ud() { local t=$(mktemp); jq ".[$1].delay = $2" "$SERVERS_FILE" > "$t" && mv "$t" "$SERVERS_FILE"; }
cd_() { local t=$(mktemp); jq '[.[] | .delay = -1]' "$SERVERS_FILE" > "$t" && mv "$t" "$SERVERS_FILE"; }
sb() { local t=$(mktemp); jq 'sort_by(if .delay<0 then 99999 else .delay end)' "$SERVERS_FILE" > "$t" && mv "$t" "$SERVERS_FILE"; }

# UI feedback functions
ok() { echo -e "  ${G}${ICON_SUCCESS}${RST} ${BD}$1${RST}"; }
wn() { echo -e "  ${Y}${ICON_WARN}${RST} ${DM}$1${RST}"; }
er() { echo -e "  ${R}${ICON_ERROR}${RST} ${BD}$1${RST}"; }

# Progress bar
progress_bar() {
    local current=$1 total=$2 width=30
    local pct=$((current*100/total))
    local filled=$((current*width/total))
    local bar=""
    for ((i=0; i<filled; i++)); do bar="${bar}${G}█${RST}"; done
    for ((i=filled; i<width; i++)); do bar="${bar}${DM}░${RST}"; done
    printf "\r  ${C}[${bar}${C}]${RST} ${BD}%3d%%${RST} (%d/%d)" "$pct" "$current" "$total"
}
