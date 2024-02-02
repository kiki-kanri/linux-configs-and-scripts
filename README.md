# ubuntu-config-and-scripts

給新建置的ubuntu22.04(或以上)系統安裝基礎程式的script與config

## Configs
1. root使用的crontab(configs/crontab/root)
  - 自動清理docker build快取 (每天3點清理)
  - 自動清理3天前 journal log crontab (每天3點清理)
  - 更新npm與pnpm與yarn (每三天3點更新)
  - 自動更新portainer (每三天3點更新，**需要複製`scripts/upgrade_portainer.sh`到`/root`資料夾**)

2. 一般用戶使用的crontab(configs/crontab/user)
  - 更新pnpm (每三天3點更新)
  - 更新yarn (每三天3點更新)

3. SSH server只允許ipv4
  ```
  AddressFamily inet
  ```

1. 關閉系統的ipv6，編輯/etc/sysctl.conf
  ```
  net.ipv6.conf.all.disable_ipv6 = 1
  net.ipv6.conf.default.disable_ipv6 = 1
  net.ipv6.conf.lo.disable_ipv6 = 1
  ```

## Scripts
- `disable_motds.sh` - 關閉help、landscape-sysinfo、motd-news與updates-available motd
- `install_base_packages.sh` - 安裝基礎套件，gcc screen tmux等
- `install_docker.sh` - 照該[文檔](https://docs.docker.com/engine/install/ubuntu/)方式安裝docker
- `install_mariadb.sh` - 安裝mariadb最新stable版本並設定服務開機自動啟動
- `install_nginx.sh` - 安裝nginx stable版本並複製`configs/nginx`相關設定檔至/etc/nginx，**注意會覆蓋掉原有設定檔**，並產生`dhparam.pem`檔案與設定服務開機自動啟動
- `install_nodejs.sh` - 安裝nodejs20
- `install_php8.sh` - 安裝php8.2與常用附屬套件
- `install_portainer.sh` 安裝portainer，需要先安裝`docker`，預設expose port為127.0.0.1:9000 -> 9000(http)
- `install_python` - 安裝python3.11
- `install_ufw_docker.sh` - 安裝ufw-docker script，請參考此[專案](https://github.com/chaifeng/ufw-docker#ufw-docker-%E5%B7%A5%E5%85%B7)
- `set_locale.sh` - 設置時區為Asia/Taipei，語系為zh_TW.UTF-8
- `upgrade_packages.sh` - 更新套件並執行autoremove與autoclean
- `upgrade_portainer.sh` - 更新portainer
