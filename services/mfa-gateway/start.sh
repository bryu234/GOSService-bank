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

install -d -m 0755 /state/nginx/snippets /state/tls
install -d -m 0700 /state/authelia /state/authelia/secrets

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
AUTHELIA_SESSION_SECRET_FILE=/state/authelia/secrets/session
AUTHELIA_STORAGE_ENCRYPTION_KEY_FILE=/state/authelia/secrets/storage-encryption
AUTHELIA_IDENTITY_VALIDATION_RESET_PASSWORD_JWT_SECRET_FILE=/state/authelia/secrets/reset-jwt
AUTHELIA_AUTHENTICATION_BACKEND_LDAP_PASSWORD_FILE=/state/authelia/secrets/ldap-password
EOF
chmod 0600 /state/authelia/runtime.env /state/authelia/secrets/*

template_vars='${MFA_GATEWAY_ROLE} ${MFA_APP_DOMAIN} ${MFA_AUTH_DOMAIN} ${MFA_PUBLIC_AUTHELIA_URL} ${MFA_PUBLIC_APP_URL} ${MFA_ALLOWED_GROUP} ${MFA_LDAP_BIND_DN} ${MFA_SESSION_COOKIE_NAME} ${MFA_AUTHELIA_PORT} ${BANK_LDAP_IP} ${LDAP_PORT} ${LDAP_BASE_DN} ${BANKLAB_DOMAIN}'
if [[ ! -s /state/authelia/configuration.yml.example ]]; then
  envsubst "$template_vars" </defaults/authelia.configuration.yml.example.template \
    >/state/authelia/configuration.yml.example
fi
if [[ ! -s /state/STUDENT_TASK.md || -e /state/.first-boot ]]; then
  envsubst '$MFA_GATEWAY_ROLE $MFA_APP_DOMAIN $MFA_AUTH_DOMAIN $MFA_ALLOWED_GROUP' \
    </defaults/STUDENT_TASK.md.template >/state/STUDENT_TASK.md
fi
if [[ ! -s /state/nginx/nginx.conf ]]; then
  envsubst '${MFA_APP_DOMAIN} ${MFA_AUTH_DOMAIN} ${MFA_BACKEND_IP} ${MFA_BACKEND_PORT} ${MFA_AUTHELIA_PORT}' \
    <"/defaults/nginx-${MFA_GATEWAY_ROLE}.conf.template" >/state/nginx/nginx.conf
fi
if [[ ! -s /state/nginx/snippets/authelia-authrequest.conf ]]; then
  cp /defaults/authelia-authrequest.conf /state/nginx/snippets/authelia-authrequest.conf
fi

if [[ "$MFA_GATEWAY_TLS" == 1 && ! -s /state/tls/server.crt ]]; then
  openssl req -x509 -newkey rsa:3072 -nodes -days 1825 \
    -subj "/CN=${MFA_APP_DOMAIN}" \
    -addext "subjectAltName=DNS:${MFA_APP_DOMAIN},DNS:${MFA_AUTH_DOMAIN}" \
    -keyout /state/tls/server.key -out /state/tls/server.crt
  chmod 0600 /state/tls/server.key
fi

ln -sfn /state/nginx/nginx.conf /etc/nginx/nginx.conf
nginx -t
if [[ -e /state/authelia/enabled ]]; then
  /usr/local/sbin/banklab-mfa-launch
fi
banklab_finish_initialization
exec nginx -g 'daemon off;'
