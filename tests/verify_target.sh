#!/usr/bin/env bash
set -euo pipefail

env_file="${1:-.env}"
set -a
source "$env_file"
set +a

fail() { echo "FAIL: $*" >&2; exit 1; }
pass() { echo "OK: $*"; }

for gateway in bank_mfa_dbo bank_mfa_abs; do
  docker exec "$gateway" banklab-mfa-validate >/dev/null || fail "$gateway MFA configuration is invalid"
  docker exec "$gateway" sh -ec 'banklab-mfa-status | grep -q "persistent: enabled"; banklab-mfa-status | grep -q "authelia: running"; banklab-mfa-status | grep -q "nginx auth_request: enabled"' || \
    fail "$gateway is not enabled"
done
pass "both independent MFA gateways are enabled and valid"

dbo_code="$(curl -ksS -o /dev/null -w '%{http_code}' -H 'Host: dbo.bank.lab' "https://127.0.0.1:${DBO_HOST_HTTPS_PORT}/")"
[[ "$dbo_code" == 302 ]] || fail "DBO gateway should redirect an unauthenticated client, got HTTP $dbo_code"
abs_code="$(docker exec bank_arm_oper curl -ksS -o /dev/null -w '%{http_code}' https://abs.bank.lab/sign-in)"
[[ "$abs_code" == 302 ]] || fail "ABS gateway should redirect an unauthenticated client, got HTTP $abs_code"
pass "unauthenticated DBO and ABS requests are intercepted by MFA"

docker exec bank_proxy sh -ec '! grep -q "bank_abs\|172.28.20.20" /etc/nginx/nginx.conf' || \
  fail "bank_proxy must not route ABS"
pass "DBO and ABS use separate gateways; bank_proxy does not serve ABS"

echo "TARGET infrastructure verification completed. Complete the browser TOTP checks from docs/mfa-gateways.md."
