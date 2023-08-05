# ubuntu-config-and-scripts

給新建置的ubuntu22.04(或以上)系統安裝基礎程式的script與config


## 相關設定
1. 自動清理3天前 journal log crontab (每天3點清理)
	```
	# Clear journal log
	0 3 * * * journalctl --vacuum-time=3d > /dev/null
	```

2. 自動更新portainer (每三天3點更新)
	```
	# Upgrade portainer
	0 3 */3 * * /root/upgrade_portainer.sh > /dev/null
	```

3. SSH server只允許ipv4
	```
	AddressFamily inet
	```

4. 關閉系統的ipv4，編輯/etc/sysctl.conf
	```
	net.ipv6.conf.all.disable_ipv6 = 1
	net.ipv6.conf.default.disable_ipv6 = 1
	net.ipv6.conf.lo.disable_ipv6 = 1
	```
