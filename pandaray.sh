#!/usr/bin/env bash
# ═══════════════════════════════════════════════════════════
#  PandaRay v2.0.2 — V2Ray Manager for Ubuntu
#  Install: sudo bash pandaray.sh --install
# ═══════════════════════════════════════════════════════════
set -eo pipefail
VERSION="2.0.2"
INSTALL_DIR="/opt/pandaray"
DATA_DIR="/var/lib/pandaray"
CONF_DIR="/etc/pandaray"
BIN_PATH="/usr/local/bin/pandaray"
XRAY_BIN="$INSTALL_DIR/xray"
SERVERS_FILE="$DATA_DIR/servers.json"
SETTINGS_FILE="$DATA_DIR/settings.json"
SERVICE_FILE="/etc/systemd/system/pandaray.service"
CURRENT_FILE="$DATA_DIR/current.json"

R='\033[0;31m';G='\033[0;32m';Y='\033[0;33m';C='\033[0;36m';W='\033[0;37m';BD='\033[1m';DM='\033[2m';RST='\033[0m'
PVM='\033[38;5;208m';PVL='\033[38;5;82m';PTR='\033[38;5;196m';PSS='\033[38;5;81m'
PSR='\033[38;5;214m';PHY='\033[38;5;177m';PH2='\033[38;5;213m';PTU='\033[38;5;220m'

if [[ "${1:-}" == "--install" ]]; then
    [[ $EUID -ne 0 ]] && { echo -e "${R}Run with sudo${RST}"; exit 1; }
    echo -e "${BD}Installing PandaRay v$VERSION...${RST}"
    echo "  [1/4] Dependencies..."
    export DEBIAN_FRONTEND=noninteractive
    apt-get update -qq && apt-get install -y -qq curl jq unzip systemd > /dev/null 2>&1
    echo "  [2/4] Directories..."
    mkdir -p "$INSTALL_DIR" "$DATA_DIR" "$CONF_DIR"
    chmod 777 "$DATA_DIR" "$CONF_DIR"
    echo "  [3/4] Downloading xray-core..."
    local_arch=$(uname -m)
    case "$local_arch" in x86_64) xa="64" ;; aarch64) xa="arm64-v8a" ;; *) echo "Unsupported arch"; exit 1 ;; esac
    xv=$(curl -sL https://api.github.com/repos/XTLS/Xray-core/releases/latest | jq -r '.tag_name')
    [[ -z "$xv" || "$xv" == "null" ]] && xv="v1.8.24"
    tz=$(mktemp)
    curl -sL --connect-timeout 15 --max-time 120 -o "$tz" "https://github.com/XTLS/Xray-core/releases/download/${xv}/Xray-linux-${xa}.zip" || { echo "Download failed"; rm -f "$tz"; exit 1; }
    unzip -oq "$tz" -d "$INSTALL_DIR" 2>/dev/null; chmod +x "$INSTALL_DIR/xray"; rm -f "$tz"
    echo "      xray ${xv}"
    echo '[]' > "$SERVERS_FILE"
    echo '{"test_url":"https://www.google.com/generate_204","timeout":5,"concurrent":10}' > "$SETTINGS_FILE"
    echo '{}' > "$CURRENT_FILE"
    chmod 666 "$SERVERS_FILE" "$SETTINGS_FILE" "$CURRENT_FILE"
    {
        echo '#!/usr/bin/env bash'
        echo 'set -eo pipefail'
        echo "VERSION=\"$VERSION\""
        echo "INSTALL_DIR=\"$INSTALL_DIR\""
        echo "DATA_DIR=\"$DATA_DIR\""
        echo "CONF_DIR=\"$CONF_DIR\""
        echo "BIN_PATH=\"$BIN_PATH\""
        echo "XRAY_BIN=\"$XRAY_BIN\""
        echo "SERVERS_FILE=\"$SERVERS_FILE\""
        echo "SETTINGS_FILE=\"$SETTINGS_FILE\""
        echo "SERVICE_FILE=\"$SERVICE_FILE\""
        echo "CURRENT_FILE=\"$CURRENT_FILE\""
        echo ""
        echo "R='\\033[0;31m';G='\\033[0;32m';Y='\\033[0;33m';C='\\033[0;36m';W='\\033[0;37m';BD='\\033[1m';DM='\\033[2m';RST='\\033[0m'"
        echo "PVM='\\033[38;5;208m';PVL='\\033[38;5;82m';PTR='\\033[38;5;196m';PSS='\\033[38;5;81m'"
        echo "PSR='\\033[38;5;214m';PHY='\\033[38;5;177m';PH2='\\033[38;5;213m';PTU='\\033[38;5;220m'"
        echo ""
        sed -n '/^#__BIN__#$/,$ p' "$0"
    } > "$BIN_PATH"
    chmod +x "$BIN_PATH"
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
    echo "  [4/4] Done."
    echo -e "\n  ${G}${BD}╔══════════════════════════════════════╗${RST}"
    echo -e "  ${G}${BD}║     PandaRay v$VERSION Installed       ║${RST}"
    echo -e "  ${G}${BD}╚══════════════════════════════════════╝${RST}"
    echo -e "\n  ${C}pandaray add <url>${RST}   Add subscription"
    echo -e "  ${C}pandaray test${RST}        Test & auto-sort"
    echo -e "  ${C}pandaray connect <#>${RST}  Connect"
    echo -e "  ${C}pandaray${RST}              Interactive menu\n"
    exit 0
fi

#__BIN__#

b64d(){ local s="${1//-/+}";s="${s//_/\/}";local m=$(( ${#s}%4 ));[[ $m -eq 2 ]]&&s="${s}==";[[ $m -eq 3 ]]&&s="${s}=";echo "$s"|base64 -d 2>/dev/null||true; }
urid(){ printf '%b' "${1//%/\\x}"; }
pcol(){ case "$1" in vmess) echo -ne "$PVM";;vless) echo -ne "$PVL";;trojan) echo -ne "$PTR";;ss) echo -ne "$PSS";;ssr) echo -ne "$PSR";;hysteria) echo -ne "$PHY";;hy2) echo -ne "$PH2";;tuic) echo -ne "$PTU";;*) echo -ne "$W";; esac; }
pnam(){ case "$1" in vmess)echo "VMess";;vless)echo "VLESS";;trojan)echo "Trojan";;ss)echo "SS";;ssr)echo "SSR";;hysteria)echo "Hy1";;hy2)echo "Hy2";;tuic)echo "TUIC";;*)echo "$1";; esac; }
dcol(){ local d="$1";if [[ "$d" -lt 0 ]];then echo -e "${DM}---${RST}";elif [[ "$d" -lt 150 ]];then echo -e "${G}${BD}${d}ms${RST}";elif [[ "$d" -lt 400 ]];then echo -e "${Y}${d}ms${RST}";else echo -e "${R}${d}ms${RST}";fi; }
gs(){ jq -r ".$1 // empty" "$SETTINGS_FILE"; }
ss(){ local t=$(mktemp);jq ".$1 = $2" "$SETTINGS_FILE" > "$t" && mv "$t" "$SETTINGS_FILE"; }
cs(){ jq 'length' "$SERVERS_FILE"; }
gj(){ jq -c ".[$1]" "$SERVERS_FILE"; }
as(){ local t=$(mktemp);jq ". += [$1]" "$SERVERS_FILE" > "$t" && mv "$t" "$SERVERS_FILE"; }
rs(){ local t=$(mktemp);jq "del(.[$1])" "$SERVERS_FILE" > "$t" && mv "$t" "$SERVERS_FILE"; }
ud(){ local t=$(mktemp);jq ".[$1].delay = $2" "$SERVERS_FILE" > "$t" && mv "$t" "$SERVERS_FILE"; }
cd_(){ local t=$(mktemp);jq '[.[] | .delay = -1]' "$SERVERS_FILE" > "$t" && mv "$t" "$SERVERS_FILE"; }
sb(){ local t=$(mktemp);jq 'sort_by(if .delay<0 then 99999 else .delay end)' "$SERVERS_FILE" > "$t" && mv "$t" "$SERVERS_FILE"; }
ok(){ echo -e "  ${G}✔${RST} $1"; }
wn(){ echo -e "  ${Y}⚠${RST} $1"; }
er(){ echo -e "  ${R}✘${RST} $1"; }

parse_vmess(){
    local raw="$1" j
    j=$(echo "$raw"|tr -d '\n\r '|b64d)
    [[ -z "$j" ]]&& return 1
    echo "$j"|jq -r '.add // empty' 2>/dev/null| read -r v
    [[ -z "$v" ]]&& return 1
    jq -cn --arg r "$raw" '$r|@base64d|fromjson|{protocol:"vmess",name:(.ps//"VMess"),address:.add,port:(.port//443),network:(.net//"tcp"),tls:(.tls=="tls"),delay:-1,raw:$r,extra:{id:.id,aid:(.aid//0),host:(.host//""),path:(.path//""),sni:(.sni//.host//"")}}'
}

parse_vless(){
    local u="$1"; local b="${u#vless://}"; local f="" q="" r="$b"
    [[ "$b" == *"#"* ]]&&{ f="${b##*#}";b="${b%%#*}"; };f=$(urid "${f:-VLESS}")
    [[ "$b" == *"?"* ]]&&{ q="${b##*\?}";r="${b%%\?*}"; }
    local uuid="${r%%@*}";r="${r#*@}";local addr="${r%%:*}";r="${r#*:}";local port="${r%%/*}"
    [[ "$port" == "$r" ]]&&port="$r"
    [[ -z "$addr"||-z "$port" ]]&& return 1
    local net="tcp" tls="none" host="" path="" sni="" fp="" flow="" pbk="" sid="" alpn=""
    IFS='&' read -ra pa <<< "$q"
    for p in "${pa[@]}";do k="${p%%=*}";v=$(urid "${p#*=}");case "$k" in type)net="$v";;security)tls="$v";;host)host="$v";;path)path="$v";;sni)sni="$v";;fp)fp="$v";;flow)flow="$v";;pbk)pbk="$v";;sid)sid="$v";;alpn)alpn="$v";;esac;done
    [[ -z "$sni"&&-n "$host" ]]&&sni="$host";[[ -z "$sni" ]]&&sni="$addr"
    jq -cn --arg n "$f" --arg a "$addr" --argjson p "$port" --arg u "$uuid" --arg nt "$net" --arg t "$tls" --arg h "$host" --arg pa "$path" --arg s "$sni" --arg fp "$fp" --arg fl "$flow" --arg pk "$pbk" --arg si "$sid" --arg al "$alpn" '{protocol:"vless",name:$n,address:$a,port:$p,network:$nt,tls:($t=="tls" or $t=="reality"),delay:-1,raw:"",extra:{uuid:$u,host:$h,path:$pa,sni:$s,fp:$fp,flow:$fl,pbk:$pk,sid:$si,alpn:$al,security:$t}}'
}

parse_trojan(){
    local u="$1"; local b="${u#trojan://}"; local f="" q="" r="$b"
    [[ "$b" == *"#"* ]]&&{ f="${b##*#}";b="${b%%#*}"; };f=$(urid "${f:-Trojan}")
    [[ "$b" == *"?"* ]]&&{ q="${b##*\?}";r="${b%%\?*}"; }
    local pass="${r%%@*}";r="${r#*@}";local addr="${r%%:*}";r="${r#*:}";local port="${r%%/*}"
    [[ "$port" == "$r" ]]&&port="$r"
    [[ -z "$addr"||-z "$port" ]]&& return 1
    local net="tcp" host="" path="" sni="" fp="" alpn=""
    IFS='&' read -ra pa <<< "$q"
    for p in "${pa[@]}";do k="${p%%=*}";v=$(urid "${p#*=}");case "$k" in type)net="$v";;host)host="$v";;path)path="$v";;sni)sni="$v";;fp)fp="$v";;alpn)alpn="$v";;esac;done
    [[ -z "$sni"&&-n "$host" ]]&&sni="$host";[[ -z "$sni" ]]&&sni="$addr"
    jq -cn --arg n "$f" --arg a "$addr" --argjson p "$port" --arg pw "$pass" --arg nt "$net" --arg h "$host" --arg pa "$path" --arg s "$sni" --arg fp "$fp" --arg al "$alpn" '{protocol:"trojan",name:$n,address:$a,port:$p,network:$nt,tls:true,delay:-1,raw:"",extra:{password:$pw,host:$h,path:$pa,sni:$s,fp:$fp,alpn:$al}}'
}

parse_ss(){
    local u="$1"; local b="${u#ss://}" f="" method="" pass="" addr="" port=""
    [[ "$b" == *"#"* ]]&&{ f="${b##*#}";b="${b%%#*}"; };f=$(urid "${f:-SS}")
    if [[ "$b" == *"@"* ]];then local enc="${b%%@*}";r="${b#*@}";local d=$(b64d "$enc");method="${d%%:*}";pass="${d#*:}";addr="${r%%:*}";port="${r##*:}";else local d=$(b64d "$b");method="${d%%:*}";d="${d#*:}";pass="${d%%@*}";d="${d#*@}";addr="${d%%:*}";port="${d##*:}";fi
    [[ -z "$method"||-z "$addr" ]]&& return 1
    jq -cn --arg n "$f" --arg a "$addr" --argjson p "${port:-8388}" --arg m "$method" --arg pw "$pass" '{protocol:"ss",name:$n,address:$a,port:$p,network:"tcp",tls:false,delay:-1,raw:"",extra:{method:$m,password:$pw}}'
}

parse_ssr(){
    local u="$1"; local enc="${u#ssr://}" f=""
    [[ "$enc" == *"#"* ]]&&{ f="${enc##*#}";enc="${enc%%#*}"; }
    local d=$(b64d "$enc");[[ -z "$d" ]]&& return 1
    local main="${d%%\?*}" q="${d##*\?}"
    IFS=':' read -r addr port proto method obfs opb <<< "$main"
    local op=$(b64d "$opb") rem="SSR"
    IFS='&' read -ra pa <<< "$q"
    for p in "${pa[@]}";do k="${p%%=*}";v=$(b64d "${p#*=}");case "$k" in remarks)rem="$v";;esac;done
    [[ -n "$f" ]]&&rem=$(urid "$f")
    jq -cn --arg n "$rem" --arg a "$addr" --argjson p "$port" --arg pr "$proto" --arg m "$method" --arg o "$obfs" --arg op "$op" '{protocol:"ssr",name:$n,address:$a,port:$p,network:"tcp",tls:false,delay:-1,raw:"",extra:{protocol:$pr,method:$m,obfs:$o,obfs_param:$op}}'
}

parse_hy(){
    local u="$1"; local b="${u#hysteria://}"; local f="" q="" r="$b"
    [[ "$b" == *"#"* ]]&&{ f="${b##*#}";b="${b%%#*}"; };f=$(urid "${f:-Hysteria}")
    [[ "$b" == *"?"* ]]&&{ q="${b##*\?}";r="${b%%\?*}"; }
    local addr="${r%%:*}";local port="${r##*:}"
    [[ -z "$addr"||-z "$port" ]]&& return 1
    local auth="" sni="" insecure="" obfs="" obfspa=""
    IFS='&' read -ra pa <<< "$q"
    for p in "${pa[@]}";do k="${p%%=*}";v=$(urid "${p#*=}");case "$k" in auth)auth="$v";;sni)sni="$v";;insecure)insecure="$v";;obfs)obfs="$v";;obfs-password)obfspa="$v";;esac;done
    [[ -z "$sni" ]]&&sni="$addr"
    jq -cn --arg n "$f" --arg a "$addr" --argjson p "$port" --arg au "$auth" --arg s "$sni" --arg i "$insecure" --arg o "$obfs" --arg op "$obfspa" '{protocol:"hysteria",name:$n,address:$a,port:$p,network:"udp",tls:true,delay:-1,raw:"",extra:{auth:$au,sni:$s,insecure:$i,obfs:$o,obfs_param:$op}}'
}

parse_hy2(){
    local u="$1"; local b="${u#hy2://}"; local f="" q="" r="$b" auth=""
    [[ "$b" == *"#"* ]]&&{ f="${b##*#}";b="${b%%#*}"; };f=$(urid "${f:-Hysteria2}")
    [[ "$b" == *"?"* ]]&&{ q="${b##*\?}";r="${b%%\?*}"; }
    if [[ "$r" == *"@"* ]];then auth="${r%%@*}";r="${r#*@}";fi
    local addr="${r%%:*}";local port="${r##*:}"
    [[ -z "$addr"||-z "$port" ]]&& return 1
    local sni="" insecure="" obfs="" obfspa=""
    IFS='&' read -ra pa <<< "$q"
    for p in "${pa[@]}";do k="${p%%=*}";v=$(urid "${p#*=}");case "$k" in sni)sni="$v";;insecure)insecure="$v";;obfs)obfs="$v";;obfs-password)obfspa="$v";;esac;done
    [[ -z "$sni" ]]&&sni="$addr"
    jq -cn --arg n "$f" --arg a "$addr" --argjson p "$port" --arg au "$auth" --arg s "$sni" --arg i "$insecure" --arg o "$obfs" --arg op "$obfspa" '{protocol:"hy2",name:$n,address:$a,port:$p,network:"udp",tls:true,delay:-1,raw:"",extra:{password:$au,sni:$s,insecure:$i,obfs:$o,obfs_param:$op}}'
}

parse_tuic(){
    local u="$1"; local b="${u#tuic://}"; local f="" q="" r="$b"
    [[ "$b" == *"#"* ]]&&{ f="${b##*#}";b="${b%%#*}"; };f=$(urid "${f:-TUIC}")
    [[ "$b" == *"?"* ]]&&{ q="${b##*\?}";r="${b%%\?*}"; }
    local cred="${r%%@*}";r="${r#*@}";local uuid="${cred%%:*}";local pass="${cred#*:}"
    [[ "$uuid" == "$pass" ]]&&pass=""
    local addr="${r%%:*}";local port="${r##*:}"
    [[ -z "$addr"||-z "$port" ]]&& return 1
    local sni="" alpn="" cong="" urelay=""
    IFS='&' read -ra pa <<< "$q"
    for p in "${pa[@]}";do k="${p%%=*}";v=$(urid "${p#*=}");case "$k" in sni)sni="$v";;alpn)alpn="$v";;congestion_control)cong="$v";;udp_relay_mode)urelay="$v";;esac;done
    [[ -z "$sni" ]]&&sni="$addr"
    jq -cn --arg n "$f" --arg a "$addr" --argjson p "$port" --arg u "$uuid" --arg pw "$pass" --arg s "$sni" --arg al "$alpn" --arg cg "$cong" --arg ur "$urelay" '{protocol:"tuic",name:$n,address:$a,port:$p,network:"udp",tls:true,delay:-1,raw:"",extra:{uuid:$u,password:$pw,sni:$s,alpn:$al,congestion:$cg,udp_relay:$ur}}'
}

parse_line(){
    local l="$1";l=$(echo "$l"|tr -d '\r\n ');[[ -z "$l" ]]&& return 1
    case "$l" in
        vmess://*)parse_vmess "$l";;vless://*)parse_vless "$l";;trojan://*)parse_trojan "$l";;ss://*)parse_ss "$l";;ssr://*)parse_ssr "$l";;hysteria://*)parse_hy "$l";;hy2://*)parse_hy2 "$l";;tuic://*)parse_tuic "$l";;*) return 1;;esac
}

gen_out(){
    local s="$1" pr a po ne tl ex st="{}"
    pr=$(echo "$s"|jq -r '.protocol');a=$(echo "$s"|jq -r '.address');po=$(echo "$s"|jq -r '.port');ne=$(echo "$s"|jq -r '.network');tl=$(echo "$s"|jq -r '.tls');ex=$(echo "$s"|jq -c '.extra')
    if [[ "$tl" == "true" ]];then
        local sni fp alpn ins pbk sid
        sni=$(echo "$ex"|jq -r '.sni//""');fp=$(echo "$ex"|jq -r '.fp//""');alpn=$(echo "$ex"|jq -r '.alpn//""');ins=$(echo "$ex"|jq -r '.insecure//""');pbk=$(echo "$ex"|jq -r '.pbk//""');sid=$(echo "$ex"|jq -r '.sid//""')
        if [[ -n "$pbk" ]];then
            st=$(jq -cn --arg s "$sni" --arg f "$fp" --arg k "$pbk" --arg i "$sid" '{security:"reality",realitySettings:{serverName:$s,fingerprint:($f//"chrome"),publicKey:$k,shortId:($i//"")}}')
        else
            local to=$(jq -cn --arg s "$sni" '{serverName:$s,allowInsecure:false}')
            [[ -n "$ins"&&"$ins" != "false" ]]&&to=$(jq -c '.allowInsecure=true'<<<"$to")
            [[ -n "$alpn" ]]&&to=$(jq -c --arg a "$alpn" '.alpn=($a|split(","))'<<<"$to")
            st=$(jq -cn --arg n "$ne" --argjson t "$to" '{network:$n,security:"tls",tlsSettings:$t}')
        fi
    else
        st=$(jq -cn --arg n "$ne" '{network:$n,security:"none"}')
    fi
    case "$ne" in
        ws)local h pa;h=$(echo "$ex"|jq -r '.host//""');pa=$(echo "$ex"|jq -r '.path//""');local wo="{}";[[ -n "$pa" ]]&&wo=$(jq -c --arg p "$pa" '.path=$p'<<<"$wo");[[ -n "$h" ]]&&wo=$(jq -c --arg h "$h" '.headers={Host:$h}'<<<"$wo");st=$(jq -c --argjson w "$wo" '.wsSettings=$w'<<<"$st");;
        grpc)local sv;sv=$(echo "$ex"|jq -r '.serviceName//""');[[ -n "$sv" ]]&&st=$(jq -c --arg s "$sv" '.grpcSettings={serviceName:$s}'<<<"$st");;
        h2|http)local hp hh;hp=$(echo "$ex"|jq -r '.path//"/"');hh=$(echo "$ex"|jq -r '.host//""');local ho=$(jq -cn --arg p "$hp" '{path:$p}');[[ -n "$hh" ]]&&ho=$(jq -c --arg h "$hh" '.host=[$h]'<<<"$ho");st=$(jq -c --argjson h "$ho" '.httpSettings=$h'<<<"$st");;
        kcp)local kt;kt=$(echo "$ex"|jq -r '.type//"none"');st=$(jq -c --arg t "$kt" '.kcpSettings={header:{type:$t}}'<<<"$st");;
    esac
    local se="{}"
    case "$pr" in
        vmess)local id ai;id=$(echo "$ex"|jq -r '.id');ai=$(echo "$ex"|jq -r '.aid//0');se=$(jq -cn --arg a "$a" --argjson p "$po" --arg i "$id" --argjson ai "$ai" '{vnext:[{address:$a,port:$p,users:[{id:$i,alterId:$ai,security:"auto"}]}]}');;
        vless)local uuid fl;uuid=$(echo "$ex"|jq -r '.uuid');fl=$(echo "$ex"|jq -r '.flow//""');local uo=$(jq -cn --arg i "$uuid" '{id:$i,encryption:"none"}');[[ -n "$fl" ]]&&uo=$(jq -c --arg f "$fl" '.flow=$f'<<<"$uo");se=$(jq -cn --arg a "$a" --argjson p "$po" --argjson u "$uo" '{vnext:[{address:$a,port:$p,users:[$u]}]}');;
        trojan)local pw;pw=$(echo "$ex"|jq -r '.password');se=$(jq -cn --arg a "$a" --argjson p "$po" --arg w "$pw" '{servers:[{address:$a,port:$p,password:$w}]}');;
        ss)local m pw;m=$(echo "$ex"|jq -r '.method');pw=$(echo "$ex"|jq -r '.password');se=$(jq -cn --arg a "$a" --argjson p "$po" --arg m "$m" --arg w "$pw" '{servers:[{address:$a,port:$p,method:$m,password:$w}]}');;
        hy2)local pw;pw=$(echo "$ex"|jq -r '.password//""');se=$(jq -cn --arg a "$a" --argjson p "$po" --arg w "$pw" '{servers:[{address:$a,port:$p,password:$w}]}');st=$(jq -c '.network="hysteria2"'<<<"$st");;
        hysteria)local au ob op;au=$(echo "$ex"|jq -r '.auth//""');ob=$(echo "$ex"|jq -r '.obfs//""');op=$(echo "$ex"|jq -r '.obfs_param//""');se=$(jq -cn --arg a "$a" --argjson p "$po" --arg w "$au" '{servers:[{address:$a,port:$p,password:$w}]}');st=$(jq -c '.network="hysteria2"'<<<"$st");[[ -n "$ob" ]]&&st=$(jq -c --arg o "$ob" --arg p "$op" '.hysteria2Settings={obfs:{type:$o,password:$p}}'<<<"$st");;
        tuic)local uuid pw cg;uuid=$(echo "$ex"|jq -r '.uuid');pw=$(echo "$ex"|jq -r '.password//""');cg=$(echo "$ex"|jq -r '.congestion//""');se=$(jq -cn --arg a "$a" --argjson p "$po" --arg u "$uuid" --arg w "$pw" '{servers:[{address:$a,port:$p,uuid:$u,password:$w}]}');[[ -n "$cg" ]]&&st=$(jq -c --arg c "$cg" '.congestionControl=$c'<<<"$st");;
        ssr)local pr2 m ob op;pr2=$(echo "$ex"|jq -r '.protocol');m=$(echo "$ex"|jq -r '.method');ob=$(echo "$ex"|jq -r '.obfs');op=$(echo "$ex"|jq -r '.obfs_param//""');se=$(jq -cn --arg a "$a" --argjson p "$po" --arg m "$m" --arg pr "$pr2" --arg o "$ob" --arg op "$op" '{servers:[{address:$a,port:$p,method:$m,password:"",protocol:$pr,protocolParam:"",obfs:$o,obfsParam:$op}]}');;
    esac
    jq -cn --arg pr "$pr" --argjson se "$se" --argjson st "$st" '{protocol:$pr,tag:"proxy",settings:$se,streamSettings:$st}'
}

gen_cfg(){
    local out="$1" sp="${2:-10808}" hp="${3:-10809}"
    jq -cn --argjson o "$out" --argjson sp "$sp" --argjson hp "$hp" '{log:{loglevel:"warning"},inbounds:[{tag:"socks",port:$sp,listen:"127.0.0.1",protocol:"socks",settings:{udp:true,auth:"noauth"}},{tag:"http",port:$hp,listen:"127.0.0.1",protocol:"http",settings:{allowTransparent:false}}],outbounds:[$o,{protocol:"freedom",tag:"direct"}],routing:{domainStrategy:"IPIfNonMatch",rules:[{type:"field",ip:["geoip:private","geoip:cn"],outboundTag:"direct"},{type:"field",domain:["geosite:cn"],outboundTag:"direct"}]}}'
}

fetch_sub(){
    local url="$1" t=$(mktemp) c
    c=$(curl -sL -w '%{http_code}' -o "$t" --connect-timeout 15 --max-time 60 -H "User-Agent: PandaRay/$VERSION" "$url" 2>/dev/null)||true
    if [[ "$c" != "200" ]];then er "HTTP $c";rm -f "$t";return 1;fi
    local ct=$(cat "$t");rm -f "$t";local d="$ct"
    for _ in 1 2 3;do echo "$d"|grep -qE '^(vmess|vless|trojan|ss|ssr|hysteria|hy2|tuic)://'&&break;d=$(echo "$d"|tr -d '\n\r '|b64d);done
    if ! echo "$d"|grep -qE '^(vmess|vless|trojan|ss|ssr|hysteria|hy2|tuic)://';then er "No valid links found";return 1;fi
    local n=0;while IFS= read -r l;do local s=$(parse_line "$l" 2>/dev/null)||continue;[[ -n "$s" ]]&&{ as "$s";n=$((n+1));};done <<< "$d"
    ok "Added $n server(s)"
}

test_one(){
    local i=$1 p=$2 o=$3
    local s=$(gj "$i")
    local ob=$(gen_out "$s") || true
    local cfg=$(gen_cfg "$ob" "$p" "$((p+1))") || true
    local t=$(mktemp)
    echo "$cfg" > "$t"
    "$XRAY_BIN" run -config "$t" &>/dev/null &
    local xp=$!;sleep 0.4
    local tu=$(gs test_url) to=$(gs timeout) ds
    ds=$(curl -x socks5h://127.0.0.1:$p --connect-timeout "$to" --max-time "$to" -o /dev/null -s -w '%{time_total}' "$tu" 2>/dev/null) || ds="-1"
    kill "$xp" 2>/dev/null || true; wait "$xp" 2>/dev/null || true; rm -f "$t"
    local d;if [[ "$ds" == "-1" || -z "$ds" ]];then d=-1;else d=$(echo "$ds"|awk '{printf "%.0f",$1*1000}');fi
    echo "$i:$d" > "$o"
}

cmd_test(){
    local tot=$(cs);[[ $tot -eq 0 ]]&&{ wn "No servers";return 0; };cd_
    local conc=$(gs concurrent) bp=30000 td=$(mktemp -d) pids=()
    echo -e "\n  ${BD}Testing $tot servers (${conc} concurrent)...${RST}\n"
    for((i=0;i<tot;i++));do
        test_one "$i" "$((bp+i))" "$td/$i" &
        pids+=($!)
        local dc=$((i+1))
        local pc=$((dc*100/tot)) fw=$((dc*30/tot))
        local em=$((30-fw)) bar=""
        for((b=0;b<fw;b++));do bar="${bar}█";done;for((b=0;b<em;b++));do bar="${bar}░";done
        printf "\r  ${C}[%s]${RST} %d/%d (%d%%) " "$bar" "$dc" "$tot" "$pc"
        while true;do local rn=0;for pid in "${pids[@]}";do kill -0 "$pid" 2>/dev/null&&rn=$((rn+1));done;[[ $rn -lt $conc ]]&&break;sleep 0.15;done
    done
    for pid in "${pids[@]}";do wait "$pid" 2>/dev/null||true;done
    local fb="";for((b=0;b<30;b++));do fb="${fb}█";done
    printf "\r  ${G}[%s]${RST} %d/%d (100%%) \n" "$fb" "$tot" "$tot"
    local te=0 wk=0;for f in "$td"/*;do [[ ! -f "$f" ]]&&continue;local ln=$(cat "$f");local ix="${ln%%:*}" dy="${ln##*:}";ud "$ix" "$dy";te=$((te+1));[[ "$dy" -ge 0 ]]&&wk=$((wk+1));done
    rm -rf "$td";sb;echo "";ok "Tested $te, $wk working";echo -e "  ${DM}Sorted by delay${RST}\n"
}

cmd_connect(){
    local idx=$1 tot=$(cs);[[ $tot -eq 0 ]]&&{ wn "No servers";return 1; }
    [[ -z "$idx" ]]&&{ echo -e "\n  ${BD}Select server:${RST}";cmd_list;echo -n "  > ";read -r idx; }
    idx=$((idx-1));[[ $idx -lt 0||$idx -ge $tot ]]&&{ er "Invalid number";return 1; }
    local s=$(gj "$idx")
    local nm=$(echo "$s"|jq -r '.name') pr=$(echo "$s"|jq -r '.protocol')
    local ob=$(gen_out "$s")
    local cfg=$(gen_cfg "$ob")
    echo "$cfg" > "$CONF_DIR/active.json";echo "$s" > "$CURRENT_FILE"
    systemctl stop pandaray 2>/dev/null||true;systemctl start pandaray 2>/dev/null||true;sleep 0.5
    if systemctl is-active --quiet pandaray;then
        echo -ne "  ";pcol "$pr";echo -ne "$(pnam "$pr")${RST}";echo -e " ${BD}»${RST} ${W}$nm${RST}"
        echo -e "  SOCKS5: ${C}127.0.0.1:10808${RST}  HTTP: ${C}127.0.0.1:10809${RST}";ok "Connected"
    else er "Failed. Check: journalctl -u pandaray -n 20";fi
}

cmd_disconnect(){ systemctl stop pandaray 2>/dev/null||true;echo '{}' > "$CURRENT_FILE";ok "Disconnected"; }

cmd_status(){
    if systemctl is-active --quiet pandaray;then
        local s=$(cat "$CURRENT_FILE" 2>/dev/null)
        local nm=$(echo "$s"|jq -r '.name//"?"') pr=$(echo "$s"|jq -r '.protocol//"?"') dy=$(echo "$s"|jq -r '.delay//-1')
        echo -e "  ${G}● Connected${RST}";echo -ne "  ";pcol "$pr";echo -ne "$(pnam "$pr")${RST}";echo -e " ${BD}»${RST} ${W}$nm${RST}"
        echo -ne "  Delay: ";dcol "$dy";echo ""
        echo -e "  SOCKS5: ${C}socks5://127.0.0.1:10808${RST}  HTTP: ${C}http://127.0.0.1:10809${RST}"
        echo -e "  Proxy:  ${DM}eval \$(pandaray proxy)${RST}"
    else echo -e "  ${R}● Disconnected${RST}";fi
}

cmd_list(){
    local tot=$(cs);[[ $tot -eq 0 ]]&&{ echo -e "\n  ${DM}No servers.${RST}  ${C}pandaray add <url>${RST}\n";return 0; }
    local fl="${1:-}" st=0 en=$tot
    [[ "$fl" =~ ^[0-9]+-[0-9]+$ ]]&&{ st=${fl%%-*};en=${fl##*-};[[ $en -gt $tot ]]&&en=$tot;fl=""; }
    printf "\n  ${BD}%-4s %-8s %-40s %-22s %5s %-5s %-3s %s${RST}\n" "#" "Proto" "Name" "Address" "Port" "Net" "TLS" "Delay"
    printf "  ${DM}%-4s %-8s %-40s %-22s %5s %-5s %-3s %s${RST}\n" "---" "-----" "----" "-------" "----" "---" "---" "-----"
    local n=0
    for((i=st;i<en;i++));do local s=$(gj "$i")||continue;local pr=$(echo "$s"|jq -r '.protocol')
        [[ -n "$fl"&&"$pr" != "$fl" ]]&&continue;n=$((n+1))
        local nm=$(echo "$s"|jq -r '.name'|cut -c1-38) ad=$(echo "$s"|jq -r '.address'|cut -c1-20) po=$(echo "$s"|jq -r '.port') ne=$(echo "$s"|jq -r '.network') tl=$(echo "$s"|jq -r '.tls') dy=$(echo "$s"|jq -r '.delay')
        printf "  ${W}%-4s${RST} " "$((i+1))";pcol "$pr";printf "%-8s${RST} " "$(pnam "$pr")"
        printf "${W}%-40s${RST} ${DM}%-22s${RST} %5s %-5s " "$nm" "$ad" "$po" "$ne"
        [[ "$tl" == "true" ]]&&printf "${G}yes${RST} "||printf "${DM}no${RST}  "
        dcol "$dy";printf "\n"
    done;echo -e "\n  ${DM}$n server(s)${RST}\n"
}

cmd_config(){
    local i=${1:-};[[ -z "$i" ]]&&{ echo "  Usage: pandaray config <#>";return 0; };i=$((i-1))
    local s=$(gj "$i")||{ er "Invalid #";return 1; };gen_cfg "$(gen_out "$s")"|jq .;echo -e "  ${DM}→ $CONF_DIR/active.json${RST}" >&2
}

cmd_export(){
    local i=${1:-};[[ -z "$i" ]]&&{ echo "  Usage: pandaray export <#> [file]";return 0; };i=$((i-1))
    local s=$(gj "$i")||{ er "Invalid #";return 1; };local of="${2:-$CONF_DIR/exported_${i}.json}"
    gen_cfg "$(gen_out "$s")"|jq . > "$of";ok "Exported to $of"
}

cmd_add(){
    local inp="${1:-}";[[ -z "$inp" ]]&&{ echo -n "  URL or link: ";read -r inp; };[[ -z "$inp" ]]&&{ er "No input";return 1; }
    case "$inp" in
        vmess://*|vless://*|trojan://*|ss://*|ssr://*|hysteria://*|hy2://*|tuic://*)
            local s=$(parse_line "$inp");if [[ -n "$s" ]];then as "$s";ok "Added: $(echo "$s"|jq -r '.name')";else er "Parse failed";fi;;
        http://*|https://*) fetch_sub "$inp";;
        *) er "Unrecognized format";return 1;;esac
}

cmd_paste(){
    echo -e "  ${DM}Paste links (Ctrl+D when done):${RST}";local c n=0;c=$(cat)
    while IFS= read -r l;do local s=$(parse_line "$l" 2>/dev/null)||continue;[[ -n "$s" ]]&&{ as "$s";n=$((n+1));};done <<< "$c"
    [[ $n -gt 0 ]]&&ok "Added $n"||wn "No valid links"
}

cmd_remove(){
    local i=${1:-};[[ -z "$i" ]]&&{ echo -n "  Server #: ";read -r i; };i=$((i-1))
    local s=$(gj "$i" 2>/dev/null)||{ er "Invalid #";return 1; };rs "$i";ok "Removed: $(echo "$s"|jq -r '.name')"
}

cmd_clear(){ echo -n "  Remove ALL? [y/N] ";read -r c;[[ "$c" =~ ^[Yy]$ ]]&&{ echo '[]' > "$SERVERS_FILE";ok "Cleared"; }; }

cmd_set(){
    local k="${1:-}" v="${2:-}"
    case "$k" in
        test-url)[[ -z "$v" ]]&&{ echo -n "  URL: ";read -r v; };ss test_url "\"$v\"";ok "Test URL: $v";;
        timeout)[[ -z "$v" ]]&&{ echo -n "  Seconds: ";read -r v; };ss timeout "$v";ok "Timeout: ${v}s";;
        concurrent)[[ -z "$v" ]]&&{ echo -n "  Count: ";read -r v; };ss concurrent "$v";ok "Concurrent: $v";;
        *)echo -e "  test-url    $(gs test_url)\n  timeout     $(gs timeout)s\n  concurrent  $(gs concurrent)\n  ${DM}Usage: pandaray set <key> <val>${RST}";;esac
}

cmd_proxy(){
    if systemctl is-active --quiet pandaray;then
        echo 'export http_proxy=http://127.0.0.1:10809';echo 'export https_proxy=http://127.0.0.1:10809';echo 'export all_proxy=socks5://127.0.0.1:10808';echo 'export no_proxy=localhost,127.0.0.1,::1'
    else echo 'unset http_proxy https_proxy all_proxy no_proxy';fi
}

cmd_update(){
    echo -e "  ${BD}Updating xray-core...${RST}";local la=$(uname -m) xa
    case "$la" in x86_64)xa="64";;aarch64)xa="arm64-v8a";;*)er "Unsupported arch";return 1;;esac
    local xv=$(curl -sL https://api.github.com/repos/XTLS/Xray-core/releases/latest|jq -r '.tag_name')
    [[ -z "$xv"||"$xv" == "null" ]]&&{ er "Version check failed";return 1; }
    local tz=$(mktemp);curl -sL --connect-timeout 15 --max-time 120 -o "$tz" "https://github.com/XTLS/Xray-core/releases/download/${xv}/Xray-linux-${xa}.zip"||{ er "Download failed";rm -f "$tz";return 1; }
    systemctl stop pandaray 2>/dev/null||true;unzip -oq "$tz" -d "$INSTALL_DIR" 2>/dev/null;chmod +x "$XRAY_BIN";rm -f "$tz"
    systemctl start pandaray 2>/dev/null||true;ok "Updated to xray ${xv}"
}

banner(){
    local tot=$(cs) te=$(jq '[.[]|select(.delay>=0)]|length' "$SERVERS_FILE") wk=$(jq '[.[]|select(.delay>=0 and .delay<5000)]|length' "$SERVERS_FILE") st
    if systemctl is-active --quiet pandaray 2>/dev/null;then st="${G}● Connected${RST}";else st="${DM}● Disconnected${RST}";fi
    echo -e "${G}${BD}"
    echo "  ╔═══════════════════════════════════════════════╗"
    echo "  ║     ██████╗  █████╗ ███╗   ██╗██╗  ██╗       ║"
    echo "  ║     ██╔══██╗██╔══██╗████╗  ██║██║ ██╔╝       ║"
    echo "  ║     ██████╔╝███████║██╔██╗ ██║█████╔╝        ║"
    echo "  ║     ██╔══██╗██╔══██║██║╚██╗██║██╔═██╗        ║"
    echo "  ║     ██████╔╝██║  ██║██║ ╚████║██║  ██╗       ║"
    echo "  ║     ╚═════╝ ╚═╝  ╚═╝╚═╝  ╚═══╝╚═╝  ╚═╝       ║"
    echo "  ║              R a y  v$VERSION                 ║"
    echo "  ╠═══════════════════════════════════════════════╣"
    echo -e "  ║  $st                                     ║"
    echo -e "  ║  ${W}Servers:${BD} $tot${RST}  ${DM}tested:$te  working:$wk${RST}              ║"
    echo -e "  ╚═══════════════════════════════════════════════╝${RST}"
}

interactive(){
    while true;do
        banner
        echo -e "  ${BD}[1]${RST} Add subscription"
        echo -e "  ${BD}[2]${RST} Paste links"
        echo -e "  ${BD}[3]${RST} List servers"
        echo -e "  ${BD}[4]${RST} Test & sort"
        echo -e "  ${BD}[5]${RST} Connect"
        echo -e "  ${BD}[6]${RST} Disconnect"
        echo -e "  ${BD}[7]${RST} Status"
        echo -e "  ${BD}[8]${RST} Remove"
        echo -e "  ${BD}[9]${RST} Export config"
        echo -e "  ${BD}[0]${RST} Settings"
        echo -e "  ${BD}[q]${RST} Quit"
        echo "";echo -n "  ${C}>${RST} ";read -r c;echo ""
        case "$c" in
            1)echo -n "  URL: ";read -r u;cmd_add "$u";;2)cmd_paste;;3)cmd_list;;4)cmd_test;;
            5)echo -n "  #: ";read -r n;cmd_connect "$n";;6)cmd_disconnect;;7)cmd_status;;
            8)echo -n "  #: ";read -r n;cmd_remove "$n";;9)echo -n "  #: ";read -r n;cmd_config "$n";;
            0)cmd_set;;q|Q)echo -e "  ${DM}Bye.${RST}";exit 0;;*)wn "Invalid";;esac
        echo "";echo -n "  Enter to continue...";read -r
    done
}

cmd_help(){
    echo -e "${BD}PandaRay v$VERSION${RST} — V2Ray Manager\n"
    echo -e "  ${C}add${RST} <url>       Add subscription or server link"
    echo -e "  ${C}paste${RST}           Paste links from stdin"
    echo -e "  ${C}list${RST} [proto]    List servers"
    echo -e "  ${C}test${RST}            Test all & auto-sort by delay"
    echo -e "  ${C}connect${RST} <#>     Connect to server"
    echo -e "  ${C}disconnect${RST}      Stop VPN"
    echo -e "  ${C}status${RST}          Show connection status"
    echo -e "  ${C}config${RST} <#>      Show xray config"
    echo -e "  ${C}export${RST} <#> [f]  Export config to file"
    echo -e "  ${C}remove${RST} <#>      Remove server"
    echo -e "  ${C}clear${RST}           Remove all"
    echo -e "  ${C}set${RST} [k] [v]     View/change settings"
    echo -e "  ${C}proxy${RST}           Print proxy env commands"
    echo -e "  ${C}update${RST}          Update xray-core"
    echo -e "  ${C}help${RST}            This help\n"
    echo -e "  ${DM}No args = interactive mode${RST}"
    echo -e "  ${DM}Protocols: VMess VLESS Trojan SS SSR Hysteria Hysteria2 TUIC${RST}\n"
}

case "${1:-}" in
    add)cmd_add "${2:-}";;paste)cmd_paste;;list|ls)cmd_list "${2:-}";;test|ping)cmd_test;;
    connect|c)cmd_connect "${2:-}";;disconnect|d)cmd_disconnect;;status|s)cmd_status;;
    config|cf)cmd_config "${2:-}";;export|ex)cmd_export "${2:-}" "${3:-}";;remove|rm)cmd_remove "${2:-}";;
    clear)cmd_clear;;set)cmd_set "${2:-}" "${3:-}";;proxy)cmd_proxy;;update)cmd_update;;
    help|--help|-h)cmd_help;;version|--version|-v)echo "PandaRay v$VERSION";;
    "")interactive;;*)echo -e "  ${Y}Unknown: $1${RST}";cmd_help;;esac
