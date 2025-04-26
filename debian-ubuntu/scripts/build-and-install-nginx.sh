#!/bin/bash

set -e

ROOT_DIR="$(realpath "$(dirname "$(readlink -f "$0")")"/../)"
cd "$ROOT_DIR"
. ./scripts/common.sh

IS_UPGRADE='0'
NGINX_VERSION='1.28.0'

# Detect existing nginx install
if [ -f /etc/nginx/nginx.conf ]; then
    echo 'Detected existing Nginx installation.'
    echo "If you continue, it will perform an upgrade to v$NGINX_VERSION."
    echo 'All files and folders in /etc/nginx will be reset EXCEPT: certs, domains, public, and nginx.conf.'
    echo -n 'Do you want to continue? (y/N) [n]: '
    read -r user_input
    user_input="${user_input,,}"
    if [ "$user_input" != 'y' ]; then
        echo 'Aborted by user.'
        exit 1
    fi

    IS_UPGRADE='1'
else
    echo "Installing Nginx v$NGINX_VERSION..."
fi

CC_OPT_FLAGS=(
    -fipa-pta
    -flto=4
    -fomit-frame-pointer
    -fPIC
    -fstack-clash-protection
    -fstack-protector-strong
    -fstrict-aliasing
    -g
    -march=native
    -O3
    -pthread
    -Werror=format-security
    -Wformat
)

DEVELOP_PACKAGES='colormake g++ gcc libbrotli-dev libgeoip-dev libpcre3-dev libperl-dev libssl-dev libzstd-dev zlib1g-dev'
LD_OPT_FLAGS=(
    -flto=4
    -fuse-linker-plugin
    -lpthread
    -pie
    -Wl,--as-needed
    -Wl,-Bsymbolic-functions
    -Wl,--gc-sections
    -Wl,-O2
    -Wl,-z,now
    -Wl,-z,relro
)

RUNTIME_PACKAGES='geoip-bin geoip-database libbrotli1 libgeoip1 libpcre3 libperl5.* libssl3 libzstd1 zlib1g'
[ "$os_type" = 'debian' ] && CC_OPT_FLAGS+=(-Wp,-D_FORTIFY_SOURCE=2)

# Install packages
sudo apt-get update
sudo apt-get install -y --no-install-recommends $DEVELOP_PACKAGES git

#  Clone brotli module
cd /tmp
rm -fr ./ngx_brotli
git clone https://github.com/google/ngx_brotli.git --recurse-submodules

# Clone zstd module
rm -fr ./zstd-nginx-module
git clone https://github.com/tokers/zstd-nginx-module --recurse-submodules

# Copy old files if upgrading
if [ "$IS_UPGRADE" = '1' ]; then
    sudo rm -rf /tmp/nginx.old
    sudo cp -frp /etc/nginx /tmp/nginx.old
    sudo rm -rf /etc/nginx
fi

# Build and install nginx
rm -fr "./nginx-$NGINX_VERSION" "./nginx-$NGINX_VERSION.tar.gz"*
wget "http://nginx.org/download/nginx-$NGINX_VERSION.tar.gz"
tar -zxvf "./nginx-$NGINX_VERSION.tar.gz"
cd "./nginx-$NGINX_VERSION"
./configure \
    --add-module=../ngx_brotli \
    --add-module=../zstd-nginx-module \
    --conf-path=/etc/nginx/nginx.conf \
    --error-log-path=/var/log/nginx/error.log \
    --group=nginx \
    --http-client-body-temp-path=/var/cache/nginx/client_temp \
    --http-fastcgi-temp-path=/var/cache/nginx/fastcgi_temp \
    --http-log-path=/var/log/nginx/access.log \
    --http-proxy-temp-path=/var/cache/nginx/proxy_temp \
    --http-scgi-temp-path=/var/cache/nginx/scgi_temp \
    --http-uwsgi-temp-path=/var/cache/nginx/uwsgi_temp \
    --lock-path=/run/nginx.lock \
    --modules-path=/usr/lib/nginx/modules \
    --pid-path=/run/nginx.pid \
    --prefix=/etc/nginx \
    --sbin-path=/usr/sbin/nginx \
    --user=nginx \
    --with-cc-opt="${CC_OPT_FLAGS[*]}" \
    --with-compat \
    --with-file-aio \
    --with-http_addition_module \
    --with-http_auth_request_module \
    --with-http_dav_module \
    --with-http_degradation_module \
    --with-http_flv_module \
    --with-http_geoip_module=dynamic \
    --with-http_gunzip_module \
    --with-http_gzip_static_module \
    --with-http_mp4_module \
    --with-http_perl_module=dynamic \
    --with-http_random_index_module \
    --with-http_realip_module \
    --with-http_secure_link_module \
    --with-http_slice_module \
    --with-http_ssl_module \
    --with-http_stub_status_module \
    --with-http_sub_module \
    --with-http_v2_module \
    --with-http_v3_module \
    --with-ld-opt="${LD_OPT_FLAGS[*]}" \
    --with-mail \
    --with-mail_ssl_module \
    --without-poll_module \
    --without-select_module \
    --with-pcre-jit \
    --with-stream \
    --with-stream=dynamic \
    --with-stream_geoip_module \
    --with-stream_geoip_module=dynamic \
    --with-stream_realip_module \
    --with-stream_ssl_module \
    --with-stream_ssl_preread_module \
    --with-threads

colormake -j$(nproc)
sudo colormake install
sudo apt-get remove -y --auto-remove --purge $DEVELOP_PACKAGES
sudo apt-get install -y $RUNTIME_PACKAGES
cd /tmp
rm -fr "./nginx-$NGINX_VERSION" "./nginx-$NGINX_VERSION.tar.gz"* ./ngx_brotli ./zstd-nginx-module

# Configure nginx
if [ "$IS_UPGRADE" = '1' ]; then
    sudo cp -frp /tmp/nginx.old/certs \
        /tmp/nginx.old/domains \
        /tmp/nginx.old/public \
        /tmp/nginx.old/nginx.conf \
        /etc/nginx

    sudo rm -rf /tmp/nginx.old
else
    id -u nginx || sudo useradd -r -s /sbin/nologin nginx
    sudo mkdir -p /var/cache/nginx /var/log/nginx /etc/nginx/certs
    sudo openssl dhparam -dsaparam -out /etc/nginx/certs/dhparam.pem 4096
    sudo cp -frp "$ROOT_DIR/etc/nginx" /etc/
    sudo cp -fp "$ROOT_DIR/etc/systemd/system/nginx.service" /etc/systemd/system/
    sudo systemctl daemon-reload
    sudo systemctl enable nginx
    sudo cp -fp "$ROOT_DIR/scripts/generate-nginx-dhparam.pem.sh" /etc/cron.monthly/generate-nginx-dhparam.pem
fi

sudo systemctl restart nginx
