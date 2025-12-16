#!/bin/bash

## Remove and clean packages
apt-get remove --auto-remove --purge $(dpkg --list | grep 'linux-image-[0-9]' | grep -v "$(uname -r)" | awk '{ print $2 }')
apt-get autoremove -y --purge
apt-get autoclean
apt-get clean

## Remove files
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
    /etc/ssh/ssh_host_* \
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
    /var/cache/debconf/* \
    /var/crash/* \
    /var/lib/apt/lists/* \
    /var/lib/dpkg/*-old \
    /var/lib/systemd/coredump/* \
    /var/tmp/*

## Clear logs

### journal
journalctl --rotate
journalctl --vacuum-time=
rm -rf /var/log/journal/*

### /var
truncate -s 0 /var/log/btmp /var/log/lastlog /var/log/wtmp
find /var/log/ -type f -name '*.log' -exec truncate -s 0 {} +
find /var/log/ \
    -type f \
    \( -name '*.bz2' -o -name '*.gz' -o -name '*.tar' -o -name '*.xz' -o -name '*.zip' \) \
    -delete

find /var/log/ \
    -type f \( -name '*.old' -o -name '*.log.1' \) \
    -delete

## Sync and shut down
sync
echo 3 >/proc/sys/vm/drop_caches
sleep 3
fstrim -av
history -c && history -w && shutdown 0
