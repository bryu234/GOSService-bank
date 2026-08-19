#!/usr/bin/env bash
set -euo pipefail

env_file="${1:-.env}"
set -a
source "$env_file"
set +a
compose=(docker compose --env-file "$env_file" -f compose.yaml)

fail() { echo "FAIL: $*" >&2; exit 1; }
pass() { echo "OK: $*"; }

running_count="$("${compose[@]}" ps --services --status running | wc -l | tr -d ' ')"
[[ "$running_count" == 15 ]] || fail "expected 15 running machines, got $running_count"
pass "15 machines are running"

for network in untrusted dmz server database management vlan10_oper vlan20_cash vlan30_acc vlan40_it; do
  docker network inspect "bank_net_${network}" >/dev/null 2>&1 || fail "missing network bank_net_${network}"
done
pass "9 bank networks exist"

docker exec bank_router sh -ec 'test "$(cat /proc/sys/net/ipv4/ip_forward)" = 1; nft list chain inet banklab_filter forward | grep -q "policy accept"'
pass "router START forwarding is permissive"

group_list() {
  local dn="$1"
  docker exec bank_ldap ldapsearch -LLL -x -H ldap://127.0.0.1 \
    -D "$LDAP_ADMIN_DN" -w "$LDAP_ADMIN_PASSWORD" -b "ou=Groups,$LDAP_BASE_DN" \
    "(member=$dn)" cn 2>/dev/null | awk '/^cn: / {print $2}' | sort
}

assert_groups() {
  local uid="$1" ou="$2" expected="$3" actual
  actual="$(group_list "uid=$uid,ou=$ou,$LDAP_BASE_DN" | tr '\n' ' ' | sed 's/ $//')"
  [[ "$actual" == "$expected" ]] || fail "$uid groups differ: $actual"
}

assert_groups "$OPER_USER" People "abs_admin abs_read abs_write dbo_read role_oper"
assert_groups "$CASH_USER" People "abs_read abs_write acc_read role_cash"
assert_groups "$ACC_USER" People "acc_read acc_write role_acc"
assert_groups "$IT_USER" People "abs_admin abs_read abs_write dbo_admin dbo_read dbo_write mgmt_admin mgmt_read mgmt_write pam_users role_it vpn_users"
assert_groups "$SVC_SHARED_USER" Services "abs_read abs_write acc_read acc_write dbo_read dbo_write mgmt_read mgmt_write"
pass "LDAP START role matrix matches the specification"

docker exec bank_arm_oper curl -fsS "http://abs.bank.lab:${ABS_APP_PORT}/sign-in" >/dev/null
docker exec bank_arm_cash curl -fsS "http://bank_acc_sys:${ACC_APP_PORT}/" >/dev/null
docker exec bank_arm_it nc -z -w 3 bank_abs "$SSH_PORT"
docker exec bank_arm_it nc -z -w 3 bank_adm_srv "$SSH_PORT"
docker exec bank_arm_it nc -z -w 3 bank_pam "$SSH_PORT"
docker exec bank_arm_cash nc -z -w 3 bank_abs_db "$ABS_DB_PORT"
pass "START has working clients and intentionally broad network access"

docker exec bank_dbo_web grep -q 'return False' /state/mfa.py
docker exec bank_abs grep -q 'return False' /state/app/bac/mfa.py
docker exec bank_pam sh -ec '! grep -q pam_google_authenticator /state/pam/sshd'
pass "MFA is intentionally disabled in START"

docker exec -e PGPASSWORD="$ACC_DB_PASSWORD" bank_acc_sys \
  psql -h 127.0.0.1 -U "$ACC_DB_USER" -d "$ACC_DB_NAME" \
  -tAc "select 1 from llx_usergroup where nom='acc_read'" | grep -q 1 || \
  fail "Dolibarr is missing the LDAP-derived acc_read group"
pass "Dolibarr is initialized with LDAP-derived accounting groups"

echo "START verification completed successfully."
