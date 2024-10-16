#!/bin/bash

if [[ "$PPID" != '1' && "$0" != '-bash' ]]; then
	nohup bash $0 "$@" >/dev/null 2>&1 &
	exit 0
fi

# 清除未使用內核、套件、快取與檔案
apt-get remove -y --auto-remove --purge $(dpkg --list | grep 'linux-image-[0-9]' | grep -v "$(uname -r)" | awk '{ print $2 }')
apt-get autoremove -y --purge
apt-get autoclean
apt-get clean
mkdir -p /root/.ssh && touch /root/.ssh/authorized_keys
docker builder prune -af
docker container prune -f
docker image prune -af
docker network prune -f
docker system prune -af
docker volume prune -f
find / -name '*.old' -exec rm -rf {} +
find / -name '__pycache__' -prune -exec rm -rf {} +
find / -name '*.py[co]' -exec rm -rf {} +
npm cache clean --force
npm cache clean -g --force
python3 -m pip cache purge
rm -rf \
	/root/.bash_history \
	/root/.bash_logout \
	/root/.cache/ \
	/root/.config/ \
	/root/.cshrc \
	/root/.docker/ \
	/root/.dotnet/ \
	/root/.lesshst \
	/root/.local/ \
	/root/.node_repl_history \
	/root/.npm \
	/root/.phpls/ \
	/root/.pip/ \
	/root/.pki/ \
	/root/.python_history \
	/root/.redhat/ \
	/root/.selected_editor \
	/root/.ssh/known_hosts* \
	/root/.tcshrc \
	/root/.viminfo \
	/root/.vscode-server/ \
	/root/.wget-hsts \
	/tmp/* \
	/var/cache/apt/* \
	/var/lib/apt/lists/* \
	/var/tmp/*

# 清除日誌
find /var/log/ -name '*.gz' -type f -exec rm -f {} +
find /var/log/ -name '*.log' -exec truncate -s 0 {} +
find /var/log/ -name '*.tar' -type f -exec rm -f {} +
find /var/log/ -name '*.xz' -type f -exec rm -f {} +
find /var/log/ -name '*.zip' -type f -exec rm -f {} +
journalctl --rotate
journalctl --vacuum-time=1s
truncate -s 0 /var/log/btmp /var/log/lastlog /var/log/wtmp

# 關閉系統
sync
echo 3 >/proc/sys/vm/drop_caches
sleep 3
fstrim -av
history -c && history -w && shutdown 0
