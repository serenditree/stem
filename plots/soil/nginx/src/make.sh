#!/usr/bin/env bash
set -o errexit

for GITHUB_REPO in nginx/nginx nginx/nginx-otel; do
    git clone https://github.com/${GITHUB_REPO}.git
done

pushd nginx
./auto/configure \
    --with-compat \
    --with-http_ssl_module \
    --with-http_sub_module \
    --with-threads \
    --user=1001 \
    --group=0 \
    --add-dynamic-module="/nginx-otel" \
    --prefix="$NGINX_ROOT"

make -j"$(nproc)"
make -j"$(nproc)" modules
make install

mkdir -pv "${NGINX_ROOT}"/{modules,cache}
cp -v ./objs/ngx_otel_module.so "${NGINX_ROOT}/modules"
ln -sfv /dev/stdout "${NGINX_ROOT}/logs/access.log"
ln -sfv /dev/stderr "${NGINX_ROOT}/logs/error.log"
