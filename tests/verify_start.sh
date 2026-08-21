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
[[ "$running_count" == 17 ]] || fail "expected 17 running machines, got $running_count"
pass "17 machines are running"

for network in untrusted dmz server database management vlan10_oper vlan20_cash vlan30_acc vlan40_it; do
  docker network inspect "bank_net_${network}" >/dev/null 2>&1 || fail "missing network bank_net_${network}"
done
pass "9 bank networks exist"

docker exec bank_router sh -ec 'test "$(cat /proc/sys/net/ipv4/ip_forward)" = 1; nft list chain inet banklab_filter forward | grep -q "policy accept"'
pass "router START forwarding is permissive"

for port in "$ARM_OPER_HOST_SSH_PORT" "$ARM_CASH_HOST_SSH_PORT" "$ARM_ACC_HOST_SSH_PORT" "$ARM_IT_HOST_SSH_PORT" \
            "$ARM_OPER_HOST_RDP_PORT" "$ARM_CASH_HOST_RDP_PORT" "$ARM_ACC_HOST_RDP_PORT" "$ARM_IT_HOST_RDP_PORT"; do
  docker port bank_router "${port}/tcp" | grep -q ":${port}$" || fail "router does not publish ARM port $port"
  docker exec bank_router nft -n list chain ip banklab_nat prerouting | \
    grep -q "tcp dport ${port} dnat" || fail "router is missing DNAT for ARM port $port"
done
pass "router publishes and DNATs all 8 ARM access ports"

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

docker exec bank_arm_oper curl -kfsS "https://abs.bank.lab/sign-in" >/dev/null
docker exec bank_arm_cash curl -fsS "http://bank_acc_sys:${ACC_APP_PORT}/" >/dev/null
docker exec bank_arm_it nc -z -w 3 bank_abs "$SSH_PORT"
docker exec bank_arm_it nc -z -w 3 bank_adm_srv "$SSH_PORT"
docker exec bank_arm_it nc -z -w 3 bank_pam "$SSH_PORT"
docker exec bank_arm_cash nc -z -w 3 bank_abs_db "$ABS_DB_PORT"
pass "START has working clients and intentionally broad network access"

docker exec bank_proxy sh -ec 'grep -q "proxy_pass http://${BANK_MFA_DBO_IP}" /state/nginx/nginx.conf; ! grep -q "bank_abs\|${BANK_ABS_IP}" /state/nginx/nginx.conf'
docker exec bank_proxy curl -fsS -H 'Host: dbo.bank.lab' -H 'X-Forwarded-Proto: https' http://bank_mfa_dbo/ >/dev/null
docker exec bank_mfa_dbo sh -ec 'banklab-mfa-status | grep -q "persistent: START bypass"; banklab-mfa-status | grep -q "authelia: stopped"; banklab-mfa-status | grep -q "nginx auth_request: disabled"'
docker exec bank_mfa_abs sh -ec 'banklab-mfa-status | grep -q "persistent: START bypass"; banklab-mfa-status | grep -q "authelia: stopped"; banklab-mfa-status | grep -q "nginx auth_request: disabled"'
docker exec bank_pam sh -ec '! grep -q pam_google_authenticator /state/pam/sshd'
pass "both MFA gateways are present, separate and intentionally bypassed in START"

for uid in "$OPER_USER" "$CASH_USER" "$ACC_USER" "$IT_USER"; do
  docker exec bank_ldap ldapsearch -LLL -x -H ldap://127.0.0.1 \
    -D "$LDAP_ADMIN_DN" -w "$LDAP_ADMIN_PASSWORD" \
    -b "uid=$uid,ou=People,$LDAP_BASE_DN" -s base mail 2>/dev/null | grep -q "^mail: ${uid}@${BANKLAB_DOMAIN}$" || \
    fail "LDAP mail attribute is missing for $uid"
done
pass "LDAP users have mail attributes required by MFA enrollment"

docker exec -e PGPASSWORD="$ACC_DB_PASSWORD" bank_acc_sys \
  psql -h 127.0.0.1 -U "$ACC_DB_USER" -d "$ACC_DB_NAME" \
  -tAc "select 1 where exists (select from llx_usergroup where nom='acc_read') and exists (select from llx_const where entity=1 and name='MAIN_INFO_SOCIETE_NOM' and value <> '') and exists (select from llx_const where entity=1 and name='MAIN_INFO_SOCIETE_COUNTRY' and value <> '')" | grep -q 1 || \
  fail "Dolibarr is missing its company profile or LDAP-derived acc_read group"
pass "Dolibarr is initialized with LDAP-derived accounting groups"

echo "START verification completed successfully."
