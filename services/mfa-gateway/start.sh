#!/usr/bin/env bash
set -euo pipefail
source /usr/local/lib/banklab-common.sh

banklab_require MFA_GATEWAY_ROLE MFA_APP_DOMAIN MFA_AUTH_DOMAIN MFA_PUBLIC_AUTHELIA_URL \
  MFA_PUBLIC_APP_URL MFA_BACKEND_IP MFA_BACKEND_PORT MFA_ALLOWED_GROUP MFA_LDAP_BIND_DN \
  MFA_LDAP_BIND_PASSWORD MFA_SESSION_COOKIE_NAME MFA_GATEWAY_TLS MFA_AUTHELIA_PORT \
  BANK_LDAP_IP LDAP_PORT LDAP_BASE_DN BANKLAB_DOMAIN

case "$MFA_GATEWAY_ROLE" in
  dbo|abs) ;;
  *) echo "Unsupported MFA_GATEWAY_ROLE=$MFA_GATEWAY_ROLE" >&2; exit 1 ;;
esac

banklab_init_state "bank_mfa_${MFA_GATEWAY_ROLE}"
banklab_start_support

install -d -m 0755 /state/nginx/snippets /state/nginx/log /state/tls \
  /etc/nginx/snippets /etc/ssl/certs /etc/ssl/private
install -d -m 0700 /state/authelia /state/authelia/secrets
rm -rf /etc/authelia /var/lib/authelia /var/log/authelia /var/log/nginx
ln -sfn /state/authelia /etc/authelia
ln -sfn /state/authelia /var/lib/authelia
ln -sfn /state/authelia /var/log/authelia
ln -sfn /state/nginx/log /var/log/nginx

write_random_secret() {
  local path="$1"
  if [[ ! -s "$path" ]]; then
    umask 077
    openssl rand -hex 32 >"$path"
  fi
}

write_random_secret /state/authelia/secrets/session
write_random_secret /state/authelia/secrets/storage-encryption
write_random_secret /state/authelia/secrets/reset-jwt
if [[ ! -s /state/authelia/secrets/ldap-password ]]; then
  umask 077
  printf '%s' "$MFA_LDAP_BIND_PASSWORD" >/state/authelia/secrets/ldap-password
fi

cat >/state/authelia/runtime.env <<'EOF'
AUTHELIA_SESSION_SECRET_FILE=/etc/authelia/secrets/session
AUTHELIA_STORAGE_ENCRYPTION_KEY_FILE=/etc/authelia/secrets/storage-encryption
AUTHELIA_IDENTITY_VALIDATION_RESET_PASSWORD_JWT_SECRET_FILE=/etc/authelia/secrets/reset-jwt
AUTHELIA_AUTHENTICATION_BACKEND_LDAP_PASSWORD_FILE=/etc/authelia/secrets/ldap-password
EOF
chmod 0600 /state/authelia/runtime.env /state/authelia/secrets/*

template_vars='${MFA_GATEWAY_ROLE} ${MFA_APP_DOMAIN} ${MFA_AUTH_DOMAIN} ${MFA_PUBLIC_AUTHELIA_URL} ${MFA_PUBLIC_APP_URL} ${MFA_ALLOWED_GROUP} ${MFA_LDAP_BIND_DN} ${MFA_SESSION_COOKIE_NAME} ${MFA_AUTHELIA_PORT} ${BANK_LDAP_IP} ${LDAP_PORT} ${LDAP_BASE_DN} ${BANKLAB_DOMAIN}'
if [[ ! -s /state/authelia/configuration.yml.example ]]; then
  envsubst "$template_vars" </defaults/authelia.configuration.yml.example.template \
    >/state/authelia/configuration.yml.example
fi
if [[ ! -s /state/nginx/nginx.conf ]]; then
  envsubst '${MFA_APP_DOMAIN} ${MFA_AUTH_DOMAIN} ${MFA_BACKEND_IP} ${MFA_BACKEND_PORT} ${MFA_AUTHELIA_PORT}' \
    <"/defaults/nginx-${MFA_GATEWAY_ROLE}.conf.template" >/state/nginx/nginx.conf
fi
if [[ ! -s /state/nginx/snippets/authelia-authrequest.conf ]]; then
  cp /defaults/authelia-authrequest.conf /state/nginx/snippets/authelia-authrequest.conf
fi
ln -sfn /state/nginx/snippets/authelia-authrequest.conf /etc/nginx/snippets/authelia-authrequest.conf
if [[ "$MFA_GATEWAY_ROLE" == dbo && ! -e /state/.migration-dbo-original-url-v1 ]]; then
  sed -i 's#X-Original-URL \$scheme://#X-Original-URL https://#; s#X-Forwarded-Proto \$http_x_forwarded_proto#X-Forwarded-Proto https#' \
    /state/nginx/nginx.conf
  touch /state/.migration-dbo-original-url-v1
fi

if [[ "$MFA_GATEWAY_TLS" == 1 && ! -s /state/tls/server.crt ]]; then
  openssl req -x509 -newkey rsa:3072 -nodes -days 1825 \
    -subj "/CN=${MFA_APP_DOMAIN}" \
    -addext "subjectAltName=DNS:${MFA_APP_DOMAIN},DNS:${MFA_AUTH_DOMAIN}" \
    -keyout /state/tls/server.key -out /state/tls/server.crt
  chmod 0600 /state/tls/server.key
fi

ln -sfn /state/tls/server.crt /etc/ssl/certs/banklab-mfa.crt
ln -sfn /state/tls/server.key /etc/ssl/private/banklab-mfa.key
ln -sfn /state/nginx/nginx.conf /etc/nginx/nginx.conf
nginx -t
if [[ -e /state/authelia/enabled ]]; then
  /usr/local/sbin/banklab-mfa-launch
fi
banklab_finish_initialization
exec nginx -g 'daemon off;'
