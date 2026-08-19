#!/usr/bin/env bash
set -euo pipefail
credentials_file="${1:?OpenVPN credential file is required}"
username="$(sed -n '1p' "$credentials_file")"
password_file="$(mktemp)"
trap 'rm -f "$password_file"' EXIT
chmod 0600 "$password_file"
sed -n '2p' "$credentials_file" >"$password_file"
exec ldapwhoami -x -H "ldap://${BANK_LDAP_IP}:${LDAP_PORT}" \
  -D "uid=${username},ou=People,${LDAP_BASE_DN}" -y "$password_file"
