#!/usr/bin/env bash
set -euo pipefail
source /usr/local/lib/banklab-common.sh

banklab_require BANK_MFA_DBO_IP PROXY_SERVER_NAME MFA_DBO_AUTH_DOMAIN MFA_AUTHELIA_PORT DBO_HOST_HTTPS_PORT
banklab_init_state bank_proxy
banklab_start_support

install -d -m 0755 /state/nginx /state/tls
if [[ ! -s /state/nginx/nginx.conf ]]; then
  envsubst '${PROXY_HTTP_PORT} ${PROXY_HTTPS_PORT} ${PROXY_SERVER_NAME} ${BANK_MFA_DBO_IP} ${MFA_DBO_AUTH_DOMAIN} ${MFA_AUTHELIA_PORT} ${DBO_HOST_HTTPS_PORT}' \
    </defaults/nginx.conf.template >/state/nginx/nginx.conf
fi
if [[ ! -e /state/.migration-https-host-port-v1 ]]; then
  sed -i "s#https://\$host\$request_uri#https://\$host:${DBO_HOST_HTTPS_PORT}\$request_uri#" /state/nginx/nginx.conf
  touch /state/.migration-https-host-port-v1
fi
if [[ ! -e /state/.migration-mfa-gateway-v1 ]]; then
  cp /state/nginx/nginx.conf /state/nginx/nginx.conf.pre-mfa-gateway-v1
  envsubst '${PROXY_HTTP_PORT} ${PROXY_HTTPS_PORT} ${PROXY_SERVER_NAME} ${BANK_MFA_DBO_IP} ${MFA_DBO_AUTH_DOMAIN} ${MFA_AUTHELIA_PORT} ${DBO_HOST_HTTPS_PORT}' \
    </defaults/nginx.conf.template >/state/nginx/nginx.conf
  touch /state/.migration-mfa-gateway-v1
fi
if [[ ! -s /state/tls/server.crt ]] || ! openssl x509 -in /state/tls/server.crt -noout -checkhost "$MFA_DBO_AUTH_DOMAIN" >/dev/null 2>&1; then
  openssl req -x509 -newkey rsa:3072 -nodes -days 1825 \
    -subj "/CN=${PROXY_SERVER_NAME}" \
    -addext "subjectAltName=DNS:${PROXY_SERVER_NAME},DNS:dbo.bank.lab,DNS:${MFA_DBO_AUTH_DOMAIN}" \
    -keyout /state/tls/server.key -out /state/tls/server.crt
  chmod 0600 /state/tls/server.key
fi
ln -sfn /state/nginx/nginx.conf /etc/nginx/nginx.conf
nginx -t
banklab_finish_initialization
exec nginx -g 'daemon off;'
