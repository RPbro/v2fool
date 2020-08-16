# v2fool
v2ray + websocket + nginx + tls + bbr

## Server Requirements
- Debian9+
- Linux kernel version 4.9+
- Package git/make/wget
- Port 80/443

## Installation
```shell script
sudo -i
apt update && apt install -y git wget make
git clone https://github.com/RPbro/v2fool.git
cd v2fool
make build DOMAIN=example.com WS_PATH=/example
```
## 

## Command
```shell script
cd v2fool
make start
make stop
make restart
make status
make logs
```