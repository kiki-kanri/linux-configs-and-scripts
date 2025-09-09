#!/bin/bash

set -euo pipefail

SCRIPTS_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"
BASE_DIR="$(cd -- "${SCRIPTS_DIR}/../" &>/dev/null && pwd)"
cd "${BASE_DIR}"

. ./scripts/common.sh

IS_UPGRADE='0'
NGINX_VERSION='1.28.0'

# Detect existing nginx install
if [ -f /etc/nginx/nginx.conf ]; then
    echo 'Detected existing Nginx installation'
    echo "If you continue, it will perform an upgrade to v${NGINX_VERSION}"
    echo 'All files and folders in /etc/nginx will be reset EXCEPT: certs, domains, public, and nginx.conf'
    echo 'Old files will be moved to /tmp/nginx.old'
    read -r -p 'Do you want to continue? (y/N): ' user_input
    user_input="${user_input,,}"
    if [ "${user_input}" != 'y' ]; then
        echo 'Aborted by user'
        exit 1
    fi

    IS_UPGRADE='1'
else
    echo "Installing Nginx v${NGINX_VERSION}..."
fi

# Toolchain: Clang + LLD
export AR='llvm-ar'
export CC='clang'
export CXX='clang++'
export RANLIB='llvm-ranlib'

# Packages
DEVELOP_PACKAGES=(
    clang
    colormake
    cmake
    libbrotli-dev
    libgeoip-dev
    libmaxminddb-dev
    libpcre3-dev
    libzstd-dev
    lld
    llvm
    ninja-build
    zlib1g-dev
)

RUNTIME_PACKAGES=(
    geoip-bin
    geoip-database
    libbrotli1
    libgeoip1
    libmaxminddb0
    libpcre3
    libzstd1
    zlib1g
)

# Install develop packages
sudo apt-get update
sudo apt-get install -y --no-install-recommends "${DEVELOP_PACKAGES[@]}" g++ gcc git pkg-config wget

# Temp workspace
TMP_DIR_PATH='/tmp/build-and-install-nginx'
rm -rf "${TMP_DIR_PATH}"
mkdir -p "${TMP_DIR_PATH}"
cd "${TMP_DIR_PATH}"

# Build BoringSSL
BUILD_BORING_SSL_C_FLAGS=(
    -fdata-sections
    -ffunction-sections
    -flto=thin
    -fomit-frame-pointer
    -fPIC
    -fstack-clash-protection
    -fstack-protector-strong
    -fstrict-aliasing
    -g
    -march=native
    -O3
    -pthread
)

BUILD_BORING_SSL_LINKER_FLAGS=(
    -flto=thin
    -fuse-ld=lld
)

rm -rf ./boringssl
git clone https://boringssl.googlesource.com/boringssl
cmake \
    -S ./boringssl \
    -B ./boringssl/build \
    -GNinja \
    -DBUILD_TESTING=OFF \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_INTERPROCEDURAL_OPTIMIZATION=ON \
    -DCMAKE_C_FLAGS_RELEASE="${BUILD_BORING_SSL_C_FLAGS[*]}" \
    -DCMAKE_CXX_FLAGS_RELEASE="${BUILD_BORING_SSL_C_FLAGS[*]}" \
    -DCMAKE_EXE_LINKER_FLAGS_RELEASE="${BUILD_BORING_SSL_LINKER_FLAGS[*]}" \
    -DCMAKE_SHARED_LINKER_FLAGS_RELEASE="${BUILD_BORING_SSL_LINKER_FLAGS[*]}"

ninja -C ./boringssl/build -j"$(nproc)"

#  Clone brotli module
rm -rf ./ngx_brotli
git clone https://github.com/google/ngx_brotli.git --recurse-submodules &

# Clone GeoIp2 module
rm -rf ./ngx_http_geoip2_module
git clone https://github.com/leev/ngx_http_geoip2_module --recurse-submodules &

# Clone zstd module
rm -rf ./zstd-nginx-module
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
BORING_BUILD="${TMP_DIR_PATH}/boringssl/build"
BORING_INC="${TMP_DIR_PATH}/boringssl/include"
BUILD_NGINX_CC_OPT_FLAGS=(
    -fdata-sections
    -ffunction-sections
    -flto=thin
    -fomit-frame-pointer
    -fPIC
    -fstack-clash-protection
    -fstack-protector-strong
    -fstrict-aliasing
    -g
    -I${BORING_INC}
    -march=native
    -O3
    -pthread
    -Werror=format-security
    -Wformat
)

[ "${os_type}" = 'debian' ] && BUILD_NGINX_CC_OPT_FLAGS+=(-Wp,-D_FORTIFY_SOURCE=2)

BUILD_NGINX_LD_OPT_FLAGS=(
    -flto=thin
    -fuse-ld=lld
    -L${BORING_BUILD}
    -lpthread
    -lstdc++
    -Wl,--as-needed
    -Wl,--gc-sections
    -Wl,-O2
    -Wl,-z,now
    -Wl,-z,relro
)

rm -rf "./nginx-${NGINX_VERSION}" "./nginx-${NGINX_VERSION}.tar.gz"*
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
    --with-cc-opt="${BUILD_NGINX_CC_OPT_FLAGS[*]}" \
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
    --with-ld-opt="${BUILD_NGINX_LD_OPT_FLAGS[*]}" \
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

colormake -j"$(nproc)"
sudo colormake install

# Configure nginx
cd "${BASE_DIR}"

if [ "${IS_UPGRADE}" = '1' ]; then
    sudo cp -frp \
        /tmp/nginx.old/certs \
        /tmp/nginx.old/domains \
        /tmp/nginx.old/public \
        /tmp/nginx.old/nginx.conf \
        /etc/nginx
else
    id -u nginx || sudo useradd -r -s /sbin/nologin nginx
    sudo mkdir -p /var/cache/nginx /var/log/nginx /etc/nginx/certs
    sudo cp -frp ./etc/nginx /etc/
    sudo cp -fp ./etc/systemd/system/nginx.service /etc/systemd/system/
    sudo systemctl daemon-reload
    sudo systemctl enable nginx
    sudo apt-mark hold nginx*
fi

sudo systemctl restart nginx

# Cleanup
sudo apt-get remove -y --auto-remove --purge "${DEVELOP_PACKAGES[@]}"
sudo apt-get install -y "${RUNTIME_PACKAGES[@]}"
sudo rm -rf "${TMP_DIR_PATH}"
sudo rm -rf /usr/lib/nginx/modules/*.old
