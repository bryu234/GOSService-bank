#!/usr/bin/env bash
set -euo pipefail

config=/state/authelia/configuration.yml
runtime=/state/authelia/runtime.env
[[ -s "$config" ]] || { echo "Create $config from configuration.yml.example" >&2; exit 1; }
[[ -s "$runtime" ]] || { echo "$runtime is missing" >&2; exit 1; }
grep -Eq "^[[:space:]]+policy:[[:space:]]*['\"]?two_factor" "$config" || {
  echo "Authelia policy two_factor is not configured" >&2; exit 1;
}
grep -Eq '^[[:space:]]*include[[:space:]]+/state/nginx/snippets/authelia-authrequest\.conf;' \
  /state/nginx/nginx.conf || {
  echo "nginx auth_request include is not enabled" >&2; exit 1;
}
set -a
source "$runtime"
set +a
authelia config validate --config "$config"
nginx -t -c /state/nginx/nginx.conf
echo "MFA gateway configuration is valid."
