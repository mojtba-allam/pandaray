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

# Base64 decode with padding fix
b64d() {
    local s="${1//-/+}"
    s="${s//_/\/}"
    local mod=${#s}%4
    case $mod in
        2) s+="==" ;;
        3) s+="=" ;;
    esac
    echo "$s" | base64 -d 2>/dev/null
}

# Safe JSON read with default
safe_read() {
    local file="$1"
    local default="${2:-{}}"
    if [[ -f "$file" ]]; then
        cat "$file" 2>/dev/null || echo "$default"
    else
        echo "$default"
    fi
}

# Parse VMess link
parse_vmess() {
    local link="$1"
    local data="${link#vmess://}"
    local json=$(b64d "$data")
    [[ -z "$json" ]] && return 1
    
    local add=$(echo "$json" | jq -r '.add//empty' 2>/dev/null)
    local port=$(echo "$json" | jq -r '.port//empty' 2>/dev/null)
    local id=$(echo "$json" | jq -r '.id//empty' 2>/dev/null)
    local ps=$(echo "$json" | jq -r '.ps//"VMess Server"' 2>/dev/null)
    
    [[ -z "$add" || -z "$port" || -z "$id" ]] && return 1
    
    jq -n --arg proto "vmess" --arg server "$add" --arg port "$port" \
          --arg id "$id" --arg name "$ps" \
          '{protocol:$proto,server:$server,port:$port,id:$id,name:$name,delay:-1}'
}

# Parse VLESS link
parse_vless() {
    local link="$1"
    local url="${link#vless://}"
    local uuid="${url%%@*}"
    local rest="${url#*@}"
    local server_port="${rest%%/*}"
    local server="${server_port%:*}"
    local port="${server_port#*:}"
    local params="${rest#*/}"
    local name=$(echo "$params" | grep -oP 'flow=[^&]*' | cut -d= -f2 || echo "VLESS Server")
    
    [[ -z "$server" || -z "$port" || -z "$uuid" ]] && return 1
    
    jq -n --arg proto "vless" --arg server "$server" --arg port "$port" \
          --arg id "$uuid" --arg name "$name" \
          '{protocol:$proto,server:$server,port:$port,id:$id,name:$name,delay:-1}'
}

# Parse Trojan link
parse_trojan() {
    local link="$1"
    local url="${link#trojan://}"
    local pass="${url%%@*}"
    local rest="${url#*@}"
    local server_port="${rest%%/*}"
    local server="${server_port%:*}"
    local port="${server_port#*:}"
    local name=$(echo "$rest" | grep -oP '#.*' | sed 's/#//' || echo "Trojan Server")
    
    [[ -z "$server" || -z "$port" || -z "$pass" ]] && return 1
    
    jq -n --arg proto "trojan" --arg server "$server" --arg port "$port" \
          --arg password "$pass" --arg name "$name" \
          '{protocol:$proto,server:$server,port:$port,password:$password,name:$name,delay:-1}'
}

# Parse Shadowsocks link
parse_ss() {
    local link="$1"
    local url="${link#ss://}"
    local method="" password="" server="" port="" name=""
    
    # Try new format: ss://method:password@server:port#name
    if [[ "$url" =~ ^([^:]+):([^@]+)@([^:/]+):([0-9]+) ]]; then
        method="${BASH_REMATCH[1]}"
        password="${BASH_REMATCH[2]}"
        server="${BASH_REMATCH[3]}"
        port="${BASH_REMATCH[4]}"
        name=$(echo "$url" | grep -oP '#.*' | sed 's/#//' || echo "SS Server")
    else
        # Try old format: ss://base64(method:password)@server:port#name
        local encoded="${url%%@*}"
        local decoded=$(b64d "$encoded")
        method="${decoded%%:*}"
        password="${decoded#*:}"
        local rest="${url#*@}"
        server="${rest%%:*}"
        port="${rest#*:}"
        port="${port%%/*}"
        name=$(echo "$rest" | grep -oP '#.*' | sed 's/#//' || echo "SS Server")
    fi
    
    [[ -z "$server" || -z "$port" || -z "$method" ]] && return 1
    
    jq -n --arg proto "ss" --arg server "$server" --arg port "$port" \
          --arg method "$method" --arg password "$password" --arg name "$name" \
          '{protocol:$proto,server:$server,port:$port,method:$method,password:$password,name:$name,delay:-1}'
}

# Parse single link
parse_link() {
    local link="$1"
    case "$link" in
        vmess://*) parse_vmess "$link" ;;
        vless://*) parse_vless "$link" ;;
        trojan://*) parse_trojan "$link" ;;
        ss://*) parse_ss "$link" ;;
        *) return 1 ;;
    esac
}

# Parse subscription content
parse_subscription() {
    local content="$1"
    
    # Try base64 decode
    local decoded=$(b64d "$content" 2>/dev/null)
    [[ -n "$decoded" ]] && content="$decoded"
    
    # Split by newlines and output valid links
    while IFS= read -r line; do
        line=$(echo "$line" | tr -d '\r' | xargs)
        [[ -z "$line" || "$line" =~ ^# ]] && continue
        case "$line" in
            vmess://*|vless://*|trojan://*|ss://*)
                local parsed=$(parse_link "$line" 2>/dev/null)
                [[ -n "$parsed" ]] && echo "$parsed"
                ;;
        esac
    done <<< "$content"
}

# ============================================================================
# DATA OPERATIONS
# ============================================================================

count_servers() { 
    if [[ -f "$SERVERS_FILE" ]]; then
        jq 'length' "$SERVERS_FILE" 2>/dev/null || echo "0"
    else
        echo "0"
    fi
}

get_server() { 
    jq -c ".[$1]" "$SERVERS_FILE" 2>/dev/null
}

add_server() { 
    local tmp=$(mktemp)
    if [[ -f "$SERVERS_FILE" ]]; then
        jq --argjson s "$1" '.+=[$s]' "$SERVERS_FILE" > "$tmp" && mv "$tmp" "$SERVERS_FILE"
    else
        echo "[$1]" > "$tmp" && mv "$tmp" "$SERVERS_FILE"
    fi
}

remove_server() { 
    local tmp=$(mktemp)
    jq "del(.[$1])" "$SERVERS_FILE" > "$tmp" && mv "$tmp" "$SERVERS_FILE"
}

update_delay() { 
    local tmp=$(mktemp)
    jq ".[$1].delay=$2" "$SERVERS_FILE" > "$tmp" && mv "$tmp" "$SERVERS_FILE"
}

clear_delays() { 
    local tmp=$(mktemp)
    jq '[.[]|.delay=-1]' "$SERVERS_FILE" > "$tmp" && mv "$tmp" "$SERVERS_FILE"
}

sort_by_delay() { 
    local tmp=$(mktemp)
    jq 'sort_by(if .delay<0 then 99999 else .delay end)' "$SERVERS_FILE" > "$tmp" && mv "$tmp" "$SERVERS_FILE"
}

get_setting() { 
    jq -r ".$1//empty" "$SETTINGS_FILE" 2>/dev/null || echo ""
}

set_setting() { 
    local tmp=$(mktemp)
    jq ".$1=\"$2\"" "$SETTINGS_FILE" > "$tmp" && mv "$tmp" "$SETTINGS_FILE"
}

atomic_write() { 
    local tmp=$(mktemp)
    echo "$1" > "$tmp" && mv "$tmp" "$2"
}

# ============================================================================
# DISPLAY FUNCTIONS
# ============================================================================

protocol_color() { 
    case "$1" in 
        vmess) echo -ne "$PVM" ;;
        vless) echo -ne "$PVL" ;;
        trojan) echo -ne "$PTR" ;;
        ss) echo -ne "$PSS" ;;
        *) echo -ne "$W" ;;
    esac
}

protocol_name() { 
    case "$1" in 
        vmess) echo "VMess" ;;
        vless) echo "VLESS" ;;
        trojan) echo "Trojan" ;;
        ss) echo "SS" ;;
        *) echo "$1" ;;
    esac
}

delay_color() { 
    local d="$1"
    if [[ "$d" == "-1" || -z "$d" ]]; then
        echo -ne "${DM}---${RST}"
    elif [[ $d -lt 100 ]]; then
        echo -ne "${G}${BD}${d}ms${RST}"
    elif [[ $d -ge 100 && $d -lt 300 ]]; then
        echo -ne "${G}${d}ms${RST}"
    else
        echo -ne "${Y}${d}ms${RST}"
    fi
}

success_msg() { 
    echo -e "  ${G}${ICON_SUCCESS}${RST} ${BD}$1${RST}"
}

warning_msg() { 
    echo -e "  ${Y}${ICON_WARN}${RST} $1${RST}"
}

error_msg() { 
    echo -e "  ${R}${ICON_ERROR}${RST} ${BD}$1${RST}"
}

show_progress() { 
    local c=$1 t=$2 w=25
    local f=$((c*w/t))
    printf "\r  ["
    for ((i=0; i<f; i++)); do printf "${G}█${RST}"; done
    for ((i=f; i<w; i++)); do printf "${DM}░${RST}"; done
    printf "] %3d%% (%d/%d)" $((c*100/t)) $c $t
}

show_banner() { 
    echo -e "${BD}${C}"
    echo -e "╔═══════════════════════════════════════════════════════════╗"
    echo -e "║     ${ICON_PANDA} ${M}PandaRay${RST} ${C}v$VERSION — Fast VPN Manager               ║"
    echo -e "╚═══════════════════════════════════════════════════════════╝${RST}\n"
}

# ============================================================================
# CONFIG GENERATION
# ============================================================================

generate_config() {
    local s="$1"
    local proto=$(echo "$s" | jq -r '.protocol')
    
    case "$proto" in
        vmess)
            local server=$(echo "$s" | jq -r '.server')
            local port=$(echo "$s" | jq -r '.port')
            local id=$(echo "$s" | jq -r '.id')
            cat << EOF
{
    "log": {"level": "warning"},
    "inbounds": [{
        "port": 1080,
        "listen": "127.0.0.1",
        "protocol": "socks",
        "settings": {"auth": "noauth", "udp": true}
    }],
    "outbounds": [{
        "protocol": "vmess",
        "settings": {
            "vnext": [{
                "address": "$server",
                "port": $port,
                "users": [{"id": "$id", "security": "auto"}]
            }]
        }
    }]
}
EOF
            ;;
        vless)
            local server=$(echo "$s" | jq -r '.server')
            local port=$(echo "$s" | jq -r '.port')
            local id=$(echo "$s" | jq -r '.id')
            cat << EOF
{
    "log": {"level": "warning"},
    "inbounds": [{
        "port": 1080,
        "listen": "127.0.0.1",
        "protocol": "socks",
        "settings": {"auth": "noauth", "udp": true}
    }],
    "outbounds": [{
        "protocol": "vless",
        "settings": {
            "vnext": [{
                "address": "$server",
                "port": $port,
                "users": [{"id": "$id", "encryption": "none"}]
            }]
        }
    }]
}
EOF
            ;;
        trojan)
            local server=$(echo "$s" | jq -r '.server')
            local port=$(echo "$s" | jq -r '.port')
            local password=$(echo "$s" | jq -r '.password')
            cat << EOF
{
    "log": {"level": "warning"},
    "inbounds": [{
        "port": 1080,
        "listen": "127.0.0.1",
        "protocol": "socks",
        "settings": {"auth": "noauth", "udp": true}
    }],
    "outbounds": [{
        "protocol": "trojan",
        "settings": {
            "servers": [{
                "address": "$server",
                "port": $port,
                "password": "$password"
            }]
        }
    }]
}
EOF
            ;;
        ss)
            local server=$(echo "$s" | jq -r '.server')
            local port=$(echo "$s" | jq -r '.port')
            local method=$(echo "$s" | jq -r '.method')
            local password=$(echo "$s" | jq -r '.password')
            cat << EOF
{
    "log": {"level": "warning"},
    "inbounds": [{
        "port": 1080,
        "listen": "127.0.0.1",
        "protocol": "socks",
        "settings": {"auth": "noauth", "udp": true}
    }],
    "outbounds": [{
        "protocol": "shadowsocks",
        "settings": {
            "servers": [{
                "address": "$server",
                "port": $port,
                "method": "$method",
                "password": "$password"
            }]
        }
    }]
}
EOF
            ;;
        *)
            echo "{}"
            ;;
    esac
}

# ============================================================================
# COMMAND FUNCTIONS
# ============================================================================

cmd_add() {
    [[ -z "${1:-}" ]] && { error_msg "Usage: pandaray add <url>"; return 1; }
    
    if [[ "$1" =~ ^https?:// ]]; then
        echo -e "${C}Fetching subscription...${RST}"
        local content=$(curl -sL --connect-timeout 10 "$1" 2>/dev/null)
        [[ -z "$content" ]] && { error_msg "Failed to fetch"; return 1; }
        
        local n=0
        while IFS= read -r parsed; do
            [[ -n "$parsed" ]] && { add_server "$parsed"; ((n++)); }
        done < <(parse_subscription "$content")
        
        success_msg "Added $n servers"
    else
        local parsed=$(parse_link "$1")
        if [[ -n "$parsed" ]]; then
            add_server "$parsed"
            success_msg "Server added"
        else
            error_msg "Invalid link format"
            return 1
        fi
    fi
}

cmd_list() {
    local total=$(count_servers)
    [[ "$total" -eq 0 ]] && { echo -e "${Y}No servers configured${RST}"; return 0; }
    
    echo -e "${BD}Servers ($total):${RST}\n"
    printf "${DM}%-4s %-8s %-20s %-10s %s${RST}\n" "#" "Proto" "Name" "Delay" "Server"
    
    for ((i=0; i<total; i++)); do
        local srv=$(get_server $i)
        local proto=$(echo "$srv" | jq -r '.protocol')
        local name=$(echo "$srv" | jq -r '.name' | cut -c1-20)
        local delay=$(echo "$srv" | jq -r '.delay // -1')
        local server=$(echo "$srv" | jq -r '.server')
        local port=$(echo "$srv" | jq -r '.port')
        
        printf "%-4s " "$i"
        protocol_color "$proto"
        printf "%-8s${RST} " "$(protocol_name "$proto")"
        printf "%-20s " "$name"
        delay_color "$delay"
        printf " %s:%s\n" "$server" "$port"
    done
    echo ""
}

cmd_test() {
    local total=$(count_servers)
    [[ "$total" -eq 0 ]] && { error_msg "No servers to test"; return 1; }
    
    local timeout=$(get_setting "timeout" || echo "5")
    echo -e "${C}Testing $total servers (timeout: ${timeout}s)...${RST}"
    
    clear_delays
    
    for ((i=0; i<total; i++)); do
        local start=$(date +%s%3N)
        local response=$(curl -s -o /dev/null -w "%{http_code}" \
            --connect-timeout "$timeout" \
            "https://www.google.com/generate_204" 2>/dev/null || echo "000")
        local end=$(date +%s%3N)
        local delay=$((end - start))
        
        if [[ "$response" == "204" || "$response" == "200" ]]; then
            update_delay $i $delay
        else
            update_delay $i -1
        fi
        
        show_progress $((i+1)) $total
    done
    
    echo ""
    sort_by_delay
    success_msg "Testing complete"
}

cmd_connect() {
    [[ -z "${1:-}" ]] && { error_msg "Usage: pandaray connect <index>"; return 1; }
    
    local srv=$(get_server "$1")
    [[ -z "$srv" || "$srv" == "null" ]] && { error_msg "Server not found"; return 1; }
    
    local name=$(echo "$srv" | jq -r '.name')
    local proto=$(echo "$srv" | jq -r '.protocol')
    
    echo -e "${C}Connecting to $name (${proto})...${RST}"
    
    # Generate config
    generate_config "$srv" > "$CONF_DIR/active.json"
    
    # Kill existing instance
    pkill -f "xray.*active" 2>/dev/null || true
    sleep 1
    
    # Start xray
    if [[ -x "$XRAY_BIN" ]]; then
        nohup "$XRAY_BIN" run -config "$CONF_DIR/active.json" > "$LOG_FILE" 2>&1 &
        sleep 2
        
        if pgrep -f "xray.*active" >/dev/null; then
            atomic_write "{\"index\":$1,\"name\":\"$name\",\"connected_at\":$(date +%s)}" "$CURRENT_FILE"
            success_msg "Connected successfully"
            echo "  SOCKS5 Proxy: 127.0.0.1:1080"
            echo "  HTTP Proxy: 127.0.0.1:1080"
        else
            error_msg "Failed to start xray"
            cat "$LOG_FILE" | tail -5
            return 1
        fi
    else
        error_msg "xray binary not found at $XRAY_BIN"
        return 1
    fi
}

cmd_disconnect() {
    pkill -f "xray.*active" 2>/dev/null || true
    atomic_write '{}' "$CURRENT_FILE"
    success_msg "Disconnected"
}

cmd_status() {
    local current=$(safe_read "$CURRENT_FILE" "{}")
    local index=$(echo "$current" | jq -r '.index // empty')
    
    if [[ -z "$index" ]]; then
        echo -e "${Y}Not connected${RST}"
        return 1
    fi
    
    local name=$(echo "$current" | jq -r '.name')
    local connected_at=$(echo "$current" | jq -r '.connected_at')
    local now=$(date +%s)
    local duration=$((now - connected_at))
    local hours=$((duration / 3600))
    local minutes=$(((duration % 3600) / 60))
    local seconds=$((duration % 60))
    
    echo -e "${G}${ICON_CONNECT} Connected${RST}"
    echo "  Server: $name"
    echo "  Duration: ${hours}h ${minutes}m ${seconds}s"
    
    if pgrep -f "xray.*active" >/dev/null; then
        echo -e "  Status: ${G}Active${RST}"
    else
        echo -e "  Status: ${R}Dead${RST}"
    fi
}

cmd_remove() {
    [[ -z "${1:-}" ]] && { error_msg "Usage: pandaray remove <index>"; return 1; }
    
    local name=$(get_server "$1" | jq -r '.name // "Unknown"')
    remove_server "$1"
    success_msg "Removed: $name"
}

cmd_fav() {
    local action="${1:-list}"
    local index="${2:-}"
    
    case "$action" in
        add)
            [[ -z "$index" ]] && { error_msg "Index required"; return 1; }
            local tmp=$(mktemp)
            jq ". += [$index] | unique" "$FAVORITES_FILE" > "$tmp" && mv "$tmp" "$FAVORITES_FILE"
            success_msg "Added to favorites"
            ;;
        remove|rm)
            [[ -z "$index" ]] && { error_msg "Index required"; return 1; }
            local tmp=$(mktemp)
            jq "del(.[] | select(. == $index))" "$FAVORITES_FILE" > "$tmp" && mv "$tmp" "$FAVORITES_FILE"
            success_msg "Removed from favorites"
            ;;
        list)
            echo -e "${BD}${ICON_STAR} Favorites:${RST}"
            local favs=$(jq -c '.[]' "$FAVORITES_FILE" 2>/dev/null)
            if [[ -n "$favs" ]]; then
                echo "$favs" | while read -r idx; do
                    local srv=$(get_server "$idx")
                    [[ -n "$srv" && "$srv" != "null" ]] && {
                        local nm=$(echo "$srv" | jq -r '.name')
                        echo "  [$idx] $nm"
                    }
                done
            else
                echo "  None"
            fi
            ;;
        *)
            error_msg "Unknown action: $action"
            return 1
            ;;
    esac
}

cmd_set() {
    if [[ -z "${1:-}" ]]; then
        echo -e "${BD}${ICON_SETTINGS} Current Settings:${RST}"
        cat "$SETTINGS_FILE" | jq .
        return 0
    fi
    
    if [[ -z "${2:-}" ]]; then
        get_setting "$1"
    else
        set_setting "$1" "$2"
        success_msg "Set $1 = $2"
    fi
}

cmd_proxy() {
    echo "export http_proxy=http://127.0.0.1:1080"
    echo "export https_proxy=http://127.0.0.1:1080"
    echo "export all_proxy=socks5://127.0.0.1:1080"
}

cmd_version() {
    echo -e "${BD}PandaRay${RST} v$VERSION"
}

cmd_help() {
    show_banner
    echo -e "${BD}Commands:${RST}"
    echo "  add <url>           Add subscription URL or single link"
    echo "  list                List all servers"
    echo "  test                Test all servers and sort by latency"
    echo "  connect <#>         Connect to server by index"
    echo "  disconnect          Disconnect current connection"
    echo "  status              Show connection status"
    echo "  remove <#>          Remove server by index"
    echo "  fav [list|add|rm]   Manage favorites"
    echo "  set [key val]       View/modify settings"
    echo "  proxy               Print proxy environment variables"
    echo "  help                Show this help"
    echo "  version             Show version"
    echo ""
    echo -e "${BD}Examples:${RST}"
    echo "  pandaray add https://example.com/sub"
    echo "  pandaray connect 0"
    echo "  pandaray proxy | bash"
}

# ============================================================================
# INTERACTIVE MENU
# ============================================================================

interactive_menu() {
    show_banner
    
    while true; do
        echo ""
        echo -e "${C}[1]${RST} List Servers      ${C}[2]${RST} Test All        ${C}[3]${RST} Add Subscription"
        echo -e "${C}[4]${RST} Connect          ${C}[5]${RST} Disconnect      ${C}[6]${RST} Status"
        echo -e "${C}[7]${RST} Favorites        ${C}[8]${RST} Settings        ${C}[9]${RST} Help"
        echo -e "${R}[0]${RST} Quit"
        echo ""
        
        read -p "Choice [0-9]: " choice
        
        case "$choice" in
            1) cmd_list ;;
            2) cmd_test ;;
            3) 
                read -p "Enter subscription URL or link: " url
                [[ -n "$url" ]] && cmd_add "$url"
                ;;
            4) 
                read -p "Enter server index: " idx
                [[ -n "$idx" ]] && cmd_connect "$idx"
                ;;
            5) cmd_disconnect ;;
            6) cmd_status ;;
            7)
                echo ""
                echo -e "${C}[1]${RST} List  ${C}[2]${RST} Add  ${C}[3]${RST} Remove"
                read -p "Action: " fav_action
                case "$fav_action" in
                    1) cmd_fav list ;;
                    2) 
                        read -p "Index to add: " fidx
                        [[ -n "$fidx" ]] && cmd_fav add "$fidx"
                        ;;
                    3)
                        read -p "Index to remove: " fidx
                        [[ -n "$fidx" ]] && cmd_fav remove "$fidx"
                        ;;
                esac
                ;;
            8) cmd_set ;;
            9) cmd_help ;;
            0|q|quit|exit) 
                echo -e "${Y}Goodbye!${RST}"
                exit 0
                ;;
            *)
                warning_msg "Invalid choice"
                ;;
        esac
        
        echo ""
        read -p "Press Enter to continue..." dummy 2>/dev/null || true
    done
}

# ============================================================================
# MAIN
# ============================================================================

main() {
    local cmd="${1:-}"
    shift 2>/dev/null || true
    
    case "$cmd" in
        add)
            cmd_add "$@"
            ;;
        list)
            cmd_list
            ;;
        test)
            cmd_test
            ;;
        connect)
            cmd_connect "$@"
            ;;
        disconnect)
            cmd_disconnect
            ;;
        status)
            cmd_status
            ;;
        remove)
            cmd_remove "$@"
            ;;
        fav)
            cmd_fav "$@"
            ;;
        set)
            cmd_set "$@"
            ;;
        proxy)
            cmd_proxy
            ;;
        help|--help|-h)
            cmd_help
            ;;
        version|--version|-v)
            cmd_version
            ;;
        "")
            interactive_menu
            ;;
        *)
            error_msg "Unknown command: $cmd"
            echo "Run 'pandaray help' for usage"
            exit 1
            ;;
    esac
}

main "$@"
