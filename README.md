# PandaRay

A lightweight V2Ray/Xray manager for Ubuntu. Manage multiple proxy servers, test latency, and connect with a single command.

## Supported Protocols

- VMess
- VLESS (including Reality)
- Trojan
- Shadowsocks (SS)
- ShadowsocksR (SSR)
- Hysteria
- Hysteria2
- TUIC

## Installation

```bash
sudo bash pandaray.sh --install
```

This will:
- Install dependencies (curl, jq, unzip)
- Download the latest xray-core
- Set up the `pandaray` command system-wide

## Usage

### Add Servers

From a subscription URL:
```bash
pandaray add https://your-subscription-url.com/sub
```

From a direct link:
```bash
pandaray add "trojan://password@server:port?sni=example.com#MyServer"
```

Paste multiple links:
```bash
pandaray paste
```

### Test Servers

Test all servers and sort by latency:
```bash
pandaray test
```

### List Servers

```bash
pandaray list
```

Filter by protocol:
```bash
pandaray list trojan
```

### Connect

```bash
pandaray connect 1
```

This starts a local SOCKS5 proxy on `127.0.0.1:10808` and HTTP proxy on `127.0.0.1:10809`.

### Set Proxy Environment Variables

```bash
eval $(pandaray proxy)
```

### Disconnect

```bash
pandaray disconnect
```

### Status

```bash
pandaray status
```

### Export Config

Export the xray JSON config for a server:
```bash
pandaray export 1 ~/myconfig.json
```

View config without saving:
```bash
pandaray config 1
```

### Settings

View current settings:
```bash
pandaray set
```

Change test URL:
```bash
pandaray set test-url https://cp.cloudflare.com
```

Change timeout (seconds):
```bash
pandaray set timeout 10
```

Change concurrent test count:
```bash
pandaray set concurrent 20
```

### Remove Servers

```bash
pandaray remove 3
```

Remove all:
```bash
pandaray clear
```

### Update Xray Core

```bash
pandaray update
```

### Interactive Mode

Run without arguments for an interactive menu:
```bash
pandaray
```

## Requirements

- Ubuntu/Debian-based Linux
- x86_64 or aarch64 architecture
- Root access (for installation and systemd service management)

## Uninstall

```bash
sudo systemctl stop pandaray
sudo rm -f /usr/local/bin/pandaray
sudo rm -f /etc/systemd/system/pandaray.service
sudo rm -rf /opt/pandaray /var/lib/pandaray /etc/pandaray
sudo systemctl daemon-reload
```

## License

MIT
