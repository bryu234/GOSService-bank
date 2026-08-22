#!/usr/bin/env bash
set -euo pipefail
source /usr/local/lib/banklab-common.sh

banklab_require LDAP_BASE_DN LDAP_ADMIN_DN LDAP_ADMIN_PASSWORD LDAP_ORGANIZATION BANKLAB_DOMAIN \
  OPER_USER CASH_USER ACC_USER IT_USER
banklab_init_state bank_ldap
banklab_start_support
install -d -m 0750 -o openldap -g openldap /state/tls
rm -rf /etc/ldap/tls
ln -sfn /state/tls /etc/ldap/tls

if [[ -e /state/.first-boot ]]; then
  ldap_domain="$(python3 - "$LDAP_BASE_DN" <<'PY'
import sys
parts = [part.split('=', 1)[1] for part in sys.argv[1].split(',') if part.lower().startswith('dc=')]
print('.'.join(parts))
PY
)"
  printf '%s\n' \
    "slapd slapd/no_configuration boolean false" \
    "slapd slapd/domain string $ldap_domain" \
    "slapd shared/organization string $LDAP_ORGANIZATION" \
    "slapd slapd/password1 password $LDAP_ADMIN_PASSWORD" \
    "slapd slapd/password2 password $LDAP_ADMIN_PASSWORD" \
    "slapd slapd/backend select MDB" \
    "slapd slapd/purge_database boolean true" \
    "slapd slapd/move_old_database boolean true" | debconf-set-selections
  rm -rf /etc/ldap/slapd.d/* /var/lib/ldap/*
  DEBIAN_FRONTEND=noninteractive dpkg-reconfigure slapd

  openssl req -x509 -newkey rsa:3072 -nodes -days 1825 -subj '/CN=bank_ldap' \
    -addext 'subjectAltName=DNS:bank_ldap,DNS:ldap.bank.lab' \
    -keyout /state/tls/ldap.key -out /state/tls/ldap.crt
  chown openldap:openldap /state/tls/ldap.key /state/tls/ldap.crt
  chmod 0640 /state/tls/ldap.key

  slapd -h 'ldap://127.0.0.1:389/ ldapi:///' -u openldap -g openldap -d 256 >/run/slapd-init.log 2>&1 &
  slapd_pid=$!
  for _ in {1..30}; do ldapwhoami -x -H ldap://127.0.0.1 >/dev/null 2>&1 && break; sleep 1; done

  seed_file=/run/banklab-seed.ldif
  /usr/local/libexec/bank-ldap-seed >"$seed_file"
  ldapadd -x -H ldap://127.0.0.1 -D "$LDAP_ADMIN_DN" -w "$LDAP_ADMIN_PASSWORD" -f "$seed_file"

  cat >/run/banklab-tls.ldif <<EOF
dn: cn=config
changetype: modify
replace: olcTLSCertificateFile
olcTLSCertificateFile: /etc/ldap/tls/ldap.crt
-
replace: olcTLSCertificateKeyFile
olcTLSCertificateKeyFile: /etc/ldap/tls/ldap.key
EOF
  ldapmodify -Y EXTERNAL -H ldapi:/// -f /run/banklab-tls.ldif
  kill "$slapd_pid"
  wait "$slapd_pid" || true
fi

if [[ ! -e /state/.migration-mail-v1 ]]; then
  slapd -h 'ldap://127.0.0.1:389/ ldapi:///' -u openldap -g openldap -d 256 >/run/slapd-mail-migration.log 2>&1 &
  slapd_pid=$!
  for _ in {1..30}; do ldapwhoami -x -H ldap://127.0.0.1 >/dev/null 2>&1 && break; sleep 1; done
  for uid in "$OPER_USER" "$CASH_USER" "$ACC_USER" "$IT_USER"; do
    dn="uid=$uid,ou=People,$LDAP_BASE_DN"
    if ! ldapsearch -LLL -x -H ldap://127.0.0.1 -D "$LDAP_ADMIN_DN" -w "$LDAP_ADMIN_PASSWORD" \
      -b "$dn" -s base mail 2>/dev/null | grep -q '^mail: '; then
      cat >/run/banklab-mail.ldif <<EOF
dn: $dn
changetype: modify
add: mail
mail: $uid@$BANKLAB_DOMAIN
EOF
      ldapmodify -x -H ldap://127.0.0.1 -D "$LDAP_ADMIN_DN" -w "$LDAP_ADMIN_PASSWORD" \
        -f /run/banklab-mail.ldif
    fi
  done
  kill "$slapd_pid"
  wait "$slapd_pid" || true
  touch /state/.migration-mail-v1
fi

banklab_finish_initialization
exec slapd -h 'ldap:/// ldaps:/// ldapi:///' -u openldap -g openldap -d 256
