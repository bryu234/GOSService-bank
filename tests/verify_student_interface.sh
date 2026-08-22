#!/usr/bin/env bash
set -euo pipefail

env_file="${1:-.env}"
compose=(docker compose --env-file "$env_file" -f compose.yaml)

fail() { echo "FAIL: $*" >&2; exit 1; }
pass() { echo "OK: $*"; }

running_count="$("${compose[@]}" ps --services --status running | wc -l | tr -d ' ')"
[[ "$running_count" == 17 ]] || fail "expected 17 running machines, got $running_count"

if grep -R -n --include='*.md' --include='*.template' '/state' README.md STUDENT.md docs services/mfa-gateway/defaults; then
  fail "student-facing materials expose the internal persistence path"
fi
pass "student-facing materials do not expose internal persistence paths"

containers=(bank_router bank_vpn bank_proxy bank_mfa_dbo bank_dbo_web bank_mfa_abs bank_abs \
  bank_acc_sys bank_abs_db bank_ldap bank_pam bank_adm_srv bank_backup \
  bank_arm_oper bank_arm_cash bank_arm_acc bank_arm_it)
for container in "${containers[@]}"; do
  docker exec "$container" test ! -e /state/STUDENT_TASK.md || fail "$container still contains a machine task file"
  docker exec "$container" test -s /etc/nftables.conf || fail "$container lacks /etc/nftables.conf"
  docker exec "$container" test -s /etc/ssh/sshd_config || fail "$container lacks /etc/ssh/sshd_config"
done
pass "common firewall and SSH paths exist on all machines"

docker exec bank_router nft -c -f /etc/nftables.conf
docker exec bank_router sshd -t
docker exec bank_proxy nginx -t
docker exec bank_proxy test -s /etc/ssl/certs/banklab-proxy.crt
docker exec bank_vpn test -s /etc/openvpn/server/server.conf
docker exec bank_vpn test -s /etc/openvpn/client/banklab-client.ovpn

for gateway in bank_mfa_dbo bank_mfa_abs; do
  docker exec "$gateway" test -s /etc/authelia/configuration.yml.example
  docker exec "$gateway" test -s /etc/nginx/snippets/authelia-authrequest.conf
  docker exec "$gateway" test -d /var/lib/authelia
  docker exec "$gateway" test -d /var/log/authelia
  docker exec "$gateway" nginx -t
done

docker exec bank_abs_db test -s /etc/postgresql/16/main/postgresql.conf
docker exec bank_abs_db test -s /etc/postgresql/16/main/pg_hba.conf
docker exec bank_acc_sys test -s /etc/postgresql/16/main/postgresql.conf
docker exec bank_acc_sys test -s /etc/postgresql/16/main/pg_hba.conf
docker exec bank_acc_sys test -s /etc/apache2/sites-available/accounting.conf
docker exec bank_acc_sys test -s /var/www/dolibarr/htdocs/conf/conf.php
docker exec bank_pam test -s /etc/pam.d/sshd
docker exec bank_pam test -s /etc/nslcd.conf
docker exec bank_ldap test -s /etc/ldap/tls/ldap.crt
docker exec bank_backup test -s /etc/bank-backup/backup.conf
pass "service-specific production-style paths are active"

echo "Student interface verification completed successfully."
