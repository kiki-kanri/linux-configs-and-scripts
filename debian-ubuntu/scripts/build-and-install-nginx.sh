#!/bin/bash

set -e

BASE_DIR="$(realpath "$(dirname "${BASH_SOURCE[0]}")/../")"
cd "${BASE_DIR}"

. ./scripts/common.sh

IS_UPGRADE='0'
NGINX_VERSION='1.28.0'

# Detect existing nginx install
if [ -f /etc/nginx/nginx.conf ]; then
    echo 'Detected existing Nginx installation.'
    echo "If you continue, it will perform an upgrade to v${NGINX_VERSION}."
    echo 'All files and folders in /etc/nginx will be reset EXCEPT: certs, domains, modules-available, modules-enabled, public, and nginx.conf.'
    echo -n 'Do you want to continue? (y/N) [n]: '
    read -r user_input
    user_input="${user_input,,}"
    if [ "${user_input}" != 'y' ]; then
        echo 'Aborted by user.'
        exit 1
    fi

    IS_UPGRADE='1'
else
    echo "Installing Nginx v${NGINX_VERSION}..."
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

DEVELOP_PACKAGES=(
    colormake
    g++
    gcc
    libbrotli-dev
    libgeoip-dev
    libmaxminddb-dev
    libpcre3-dev
    libssl-dev
    libzstd-dev
    zlib1g-dev
)

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

RUNTIME_PACKAGES=(
    geoip-bin
    geoip-database
    libbrotli1
    libgeoip1
    libmaxminddb0
    libpcre3
    libssl3
    libzstd1
    zlib1g
)

[ "${os_type}" = 'debian' ] && CC_OPT_FLAGS+=(-Wp,-D_FORTIFY_SOURCE=2)

# Install develop packages
sudo apt-get update
sudo apt-get install -y --no-install-recommends "${DEVELOP_PACKAGES[@]}" git

# Create temp directory and switch to it
TMP_DIR_PATH='/tmp/build-and-install-nginx'
rm -rf "${TMP_DIR_PATH}"
mkdir -p "${TMP_DIR_PATH}"
cd "${TMP_DIR_PATH}"

#  Clone brotli module
rm -fr ./ngx_brotli
git clone https://github.com/google/ngx_brotli.git --recurse-submodules &

# Clone GeoIp2 module
rm -fr ./ngx_http_geoip2_module
git clone https://github.com/leev/ngx_http_geoip2_module --recurse-submodules &

# Clone lua module
# rm -fr ./lua-nginx-module
# git clone https://github.com/openresty/lua-nginx-module --recurse-submodules &

# Clone ndk
# rm -fr ./ngx_devel_kit
# git clone https://github.com/vision5/ngx_devel_kit --recurse-submodules &

# Clone zstd module
rm -fr ./zstd-nginx-module
git clone https://github.com/tokers/zstd-nginx-module --recurse-submodules &

# Wait for all git clones to finish
wait

# Copy old files if upgrading
if [ "${IS_UPGRADE}" = '1' ]; then
    sudo rm -rf /tmp/nginx.old
    sudo cp -frp /etc/nginx /tmp/nginx.old
    sudo rm -rf /etc/nginx
fi

# Build and install nginx
rm -fr "./nginx-${NGINX_VERSION}" "./nginx-${NGINX_VERSION}.tar.gz"*
wget "http://nginx.org/download/nginx-${NGINX_VERSION}.tar.gz"
tar -zxvf "./nginx-${NGINX_VERSION}.tar.gz"
cd "./nginx-${NGINX_VERSION}"
./configure \
    --add-dynamic-module=../ngx_http_geoip2_module \
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
    --with-stream_geoip_module=dynamic \
    --with-stream_realip_module \
    --with-stream_ssl_module \
    --with-stream_ssl_preread_module \
    --with-threads

colormake -j$(nproc)
sudo colormake install
sudo apt-get remove -y --auto-remove --purge "${DEVELOP_PACKAGES[@]}"
sudo apt-get install -y "${RUNTIME_PACKAGES[@]}"
cd "${BASE_DIR}"

# Configure nginx
if [ "${IS_UPGRADE}" = '1' ]; then
    sudo cp -frp \
        /tmp/nginx.old/certs \
        /tmp/nginx.old/domains \
        /tmp/nginx.old/modules-available \
        /tmp/nginx.old/modules-enabled \
        /tmp/nginx.old/public \
        /tmp/nginx.old/nginx.conf \
        /etc/nginx

    sudo rm -rf /tmp/nginx.old
else
    id -u nginx || sudo useradd -r -s /sbin/nologin nginx
    sudo mkdir -p /var/cache/nginx /var/log/nginx /etc/nginx/certs
    sudo openssl dhparam -dsaparam -out /etc/nginx/certs/dhparam.pem 4096
    sudo cp -frp ./etc/nginx /etc/
    sudo cp -fp ./etc/systemd/system/nginx.service /etc/systemd/system/
    sudo systemctl daemon-reload
    sudo systemctl enable nginx
    sudo cp -fp ./scripts/generate-nginx-dhparam.pem.sh /etc/cron.monthly/generate-nginx-dhparam.pem
fi

sudo systemctl restart nginx

# Cleanup
sudo rm -rf "${TMP_DIR_PATH}"
sudo rm -rf /usr/lib/nginx/modules/*.old
