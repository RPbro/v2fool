# 系统 Debian9+
# linux内核版本 4.9+
# 开放端口 80/443

# 已经过dns解析的域名(GCP安全组勾选开放http/https端口)
export DOMAIN  ?= example.com
# 混淆路径 example.com/example
export WS_PATH ?= /example
# uuid https://www.uuidgenerator.net
export UUID ?= 435a5868-936b-bf0c-7ac8-03df31e57f11

export TEMP_DIR  ?= /tmp
export V2RAY_DIR  ?= /usr/local/etc/v2ray
export NGINX_CONF_DIR ?= /etc/nginx/conf.d

build: clear v2ray nginx bbr stop ca start

clear:
	rm -rf $(TEMP_DIR) && mkdir $(TEMP_DIR)

ca:
	# 申请证书
	apt-get -y install wget socat
	curl https://get.acme.sh | sh
	~/.acme.sh/acme.sh --issue -d $(DOMAIN) --standalone -k ec-256
	~/.acme.sh/acme.sh --installcert -d $(DOMAIN) --fullchainpath $(PWD)/v2ray.crt --keypath $(PWD)/v2ray.key --ecc
	sed -i '/.*acme.sh --cron.*/d' /var/spool/cron/crontabs/root
	echo '0 0 15 * * '/usr/bin/make '$(PWD)'/Makefile renew' > /dev/null' >> /var/spool/cron/crontabs/root

renew:
	# 证书续期
	make stop
	/bin/bash ~/.acme.sh/acme.sh --cron -f
	make start

v2ray:
	# 安装v2ray并配置
	wget https://raw.githubusercontent.com/v2fly/fhs-install-v2ray/master/install-release.sh -P $(TEMP_DIR)
	bash $(TEMP_DIR)/install-release.sh
	rm -rf $(V2RAY_DIR)/config.json
	sed -i "s:AUTH_UUID:$(UUID):" $(PWD)/v2ray.config.json
	sed -i "s:WS_PATH:$(WS_PATH):" $(PWD)/v2ray.config.json
	cp $(PWD)/v2ray.config.json $(V2RAY_DIR)/config.json

nginx:
	# 安装nginx并配置
	apt-get -y install nginx
	rm -rf $(NGINX_CONF_DIR)/*.conf
	rm -rf $(NGINX_CONF_DIR)/../sites-enabled/*
	rm -rf $(NGINX_CONF_DIR)/../sites-available/*
	ln -s $(PWD)/v2ray.nginx.conf $(NGINX_CONF_DIR)/v2ray.nginx.conf
	sed -i "s:CA_DIR:$(PWD):" $(PWD)/v2ray.nginx.conf
	sed -i "s:WS_PATH:$(WS_PATH):" $(PWD)/v2ray.nginx.conf
	sed -i "s:DOMAIN:$(DOMAIN):" $(PWD)/v2ray.nginx.conf

bbr:
	# 开启bbr
	echo "net.core.default_qdisc=fq" >> /etc/sysctl.conf
	echo "net.ipv4.tcp_congestion_control=bbr" >> /etc/sysctl.conf
	sysctl -p
	sysctl net.ipv4.tcp_available_congestion_control
	lsmod | grep bbr

rules:
	rm -rf ./geoip.dat
	rm -rf ./geosite.dat
	# https://github.com/Loyalsoldier/v2ray-rules-dat
	wget https://github.com/Loyalsoldier/v2ray-rules-dat/releases/latest/download/geoip.dat
	wget https://github.com/Loyalsoldier/v2ray-rules-dat/releases/latest/download/geosite.dat

start:
	systemctl start nginx
	systemctl start v2ray

restart:
	systemctl restart nginx
	systemctl restart v2ray

stop:
	systemctl stop nginx
	systemctl stop v2ray

status:
	@echo "\e[31;40m-------------------------------------------------------------------------------------\e[0m"
	@echo "v2ray.service: $(shell systemctl status v2ray | grep 'Active' | awk -F 'Active:' '{print $$2}')"
	@echo "nginx.service: $(shell systemctl status nginx | grep 'Active' | awk -F 'Active:' '{print $$2}')"
	@echo "Address: $(shell cat v2ray.nginx.conf | grep server_name | head -n 1 | awk '{print $$2}' | sed 's/;//g')"
	@echo "Port: $(shell cat v2ray.nginx.conf | grep listen | head -n 1 | awk '{print $$2}' | sed 's/;//g')"
	@echo "WebsocketPath: $(shell cat v2ray.config.json | grep path | awk -F ':' '{print $$2}')"
	@echo "UUID: $(shell cat v2ray.config.json | grep id | head -n 1 | awk -F ':' '{print $$2}' | sed 's/,//g' | sed 's/ //g')"
	@echo "AlterId: $(shell cat v2ray.config.json | grep alterId | awk -F ':' '{print $$2}' | sed 's/ //g')"
	@echo "\e[31;40m-------------------------------------------------------------------------------------\e[0m"

logs:
	tail -f -n 100 /var/log/v2ray/access.log