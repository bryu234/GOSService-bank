#!/usr/bin/env bash
set -euo pipefail

runtime=/state/authelia/runtime.env
config=/state/authelia/configuration.yml
[[ -s "$runtime" && -s "$config" ]] || { echo "Authelia runtime or configuration is missing" >&2; exit 1; }
set -a
source "$runtime"
set +a

if [[ -s /run/authelia.pid ]] && kill -0 "$(cat /run/authelia.pid)" 2>/dev/null; then
  exit 0
fi

authelia config validate --config "$config"
authelia --config "$config" >>/state/authelia/authelia.log 2>&1 &
echo "$!" >/run/authelia.pid

for _ in {1..30}; do
  nc -z 127.0.0.1 "${MFA_AUTHELIA_PORT:-9091}" && exit 0
  kill -0 "$(cat /run/authelia.pid)" 2>/dev/null || break
  sleep 1
done
echo "Authelia did not become ready" >&2
tail -n 30 /state/authelia/authelia.log >&2 || true
exit 1
