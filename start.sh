#!/bin/bash

function cleanup() {
    echo -e "Script interrupted.\nThe port is not valid or not open for both TCP and UDP.\nhttps://github.com/wuqb2i4f/serv00-vless-ws/tree/main#initial-setup"
    exit 1
}

trap cleanup INT
trap cleanup TERM

base_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

function setup_services() {
    init >/dev/null 2>&1
    run_cloudflared
    run_xray >/dev/null 2>&1
}

function show_services() {
    extract_vars '^VLESS'
}

function check_services() {
    local cf_session=$(tmux list-sessions | grep -q "cf" && echo "1" || echo "0")
    local xray_session=$(tmux list-sessions | grep -q "xray" && echo "1" || echo "0")
    if [ "$cf_session" -eq 0 ]; then
        setup_services
        exit 1
    fi
    if [ "$xray_session" -eq 0 ]; then
        run_xray
        exit 1
    fi
}

function init() {
    tmux kill-session -a
    prepare_cloudflared
    prepare_xray
}

function run_cloudflared() {
    local uuid=$(uuidgen)
    local port=$(reserve_port)
    local id=$(echo $uuid | tr -d '-')
    local session="cf"
    tmux kill-session -t $session >/dev/null 2>&1
    tmux new-session -s $session -d "cd $base_dir/cloudflared && ./cloudflared tunnel --url localhost:$port --edge-ip-version auto --no-autoupdate -protocol http2 2>&1 | tee $base_dir/cloudflared/session_$session.log"
    sleep 10
    local log=$(<"$base_dir/cloudflared/session_$session.log")
    local cloudflared_address=$(echo "$log" | pcregrep -o1 'https://([^ ]+\.trycloudflare\.com)' | sed 's/https:\/\///')
    generate_configs $port $uuid $id $cloudflared_address
}

function run_xray() {
    local session="xray"
    tmux kill-session -t $session
    tmux new-session -s $session -d "cd $base_dir/xray && ./xray 2>&1 | tee $base_dir/xray/session_$session.log"
    set_cronjob $session
}

function prepare_cloudflared() {
    mkdir -p $base_dir/cloudflared
    cd $base_dir/cloudflared
    curl -Lo cloudflared.7z https://cloudflared.bowring.uk/binaries/cloudflared-freebsd-latest.7z
    7z x cloudflared.7z
    rm cloudflared.7z
    mv $(find . -name 'cloudflared*') cloudflared
    rm -rf temp
    chmod +x cloudflared
}

function prepare_xray() {
    mkdir -p $base_dir/xray
    cd $base_dir/xray
    curl -Lo xray.zip https://github.com/xtls/xray-core/releases/latest/download/xray-freebsd-64.zip
    unzip -o xray.zip
    rm xray.zip
    chmod +x xray
}

function reserve_port() {
    local port
    local settings="$base_dir/settings"
    local port_found=false
    if [ -f "$settings" ]; then
        port=$(grep '^PORT=' "$settings" | cut -d '=' -f 2)
        if check_port "$port"; then
            port_found=true
            echo $port
            return
        fi
    fi
    kill -SIGINT $$
}

function generate_configs() {
    local port="$1"
    local uuid="$2"
    local id="$3"
    local cloudflared_address="$4"
    local vless="vless://${uuid}@zula.ir:443?security=tls&sni=${cloudflared_address}&alpn=h2,http/1.1&fp=chrome&type=ws&path=/ws?ed%3D2048&host=${cloudflared_address}&encryption=none#[🇵🇱]%20[vl-tl-ws]%20[at-ar]"

    cat >$base_dir/settings <<EOF
PORT=$port
UUID=$uuid
CLOUDFLARED_ADDRESS=$cloudflared_address
VLESS=$vless
EOF

    cat >$base_dir/../public_html/sub.txt <<EOF
$vless
EOF

    cat >$base_dir/xray/config.json <<EOF
{
  "log": {
    "loglevel": "none"
  },
  "inbounds": [
    {
      "port": ${port},
      "listen": "127.0.0.1",
      "protocol": "vless",
      "settings": {
        "clients": [
          {
            "id": "${uuid}",
            "level": 0,
            "email": "wuqb2i4f@duck.com"
          }
        ],
        "decryption": "none"
      },
      "streamSettings": {
        "network": "ws",
        "security": "none",
        "wsSettings": {
          "path": "/ws?ed=2048"
        }
      }
    }
  ],
  "outbounds": [
    {
      "protocol": "freedom"
    }
  ]
}
EOF
}

function set_cronjob() {
    local fifteen_minute_cron_job="*/15 * * * *    $base_dir/start.sh check"
    local daily_cron_job="0 6 * * *    $base_dir/start.sh setup"
    crontab -rf
    {
        echo "$fifteen_minute_cron_job"
        echo "$daily_cron_job"
    } >temp_crontab
    crontab temp_crontab
    rm temp_crontab
}

function extract_vars() {
    local pattern="$1"
    local settings="$base_dir/settings"

    if [ -f "$settings" ]; then
        grep "$pattern" "$settings" | sed 's/^[^=]*=//'
    else
        echo "Error: settings file not found in $base_dir"
        return 1
    fi
}

function check_port() {
    local port=$1
    local tcp_output=$(devil port list | grep -w "$port" | grep -w "tcp" | awk '{print $1}')
    local udp_output=$(devil port list | grep -w "$port" | grep -w "udp" | awk '{print $1}')
    [[ "$tcp_output" == "$port" && "$udp_output" == "$port" ]]
}

function main() {
    local action="$1"
    case $action in
    setup)
        setup_services
        ;;
    check)
        check_services >/dev/null 2>&1
        ;;
    show)
        show_services
        ;;
    *)
        echo "Usage: $0 {setup|check|show}"
        exit 1
        ;;
    esac
}

main "$@"
