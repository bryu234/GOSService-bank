#!/usr/bin/env bash
set -euo pipefail
credentials_file="${1:?OpenVPN credential file is required}"
username="$(sed -n '1p' "$credentials_file")"
password_file="$(mktemp)"
trap 'rm -f "$password_file"' EXIT
chmod 0600 "$password_file"

# ldapwhoami reads the password file byte-for-byte.  Do not include the line
# ending from OpenVPN's two-line credentials file.
printf %s "$(sed -n '2p' "$credentials_file")" >"$password_file"

user_dn="uid=${username},ou=People,${LDAP_BASE_DN}"
ldapwhoami -x -H "ldap://${BANK_LDAP_IP}:${LDAP_PORT}" \
  -D "$user_dn" -y "$password_file" >/dev/null

ldapsearch -LLL -o ldif-wrap=no -x -H "ldap://${BANK_LDAP_IP}:${LDAP_PORT}" \
  -D "$user_dn" -y "$password_file" \
  -b "cn=vpn_users,ou=Groups,${LDAP_BASE_DN}" -s base \
  '(objectClass=groupOfNames)' member | grep -Fxq "member: $user_dn"
