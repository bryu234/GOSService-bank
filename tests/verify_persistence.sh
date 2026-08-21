#!/usr/bin/env bash
set -euo pipefail

env_file="${1:-.env}"
compose=(docker compose --env-file "$env_file" -f compose.yaml)
containers=(bank_arm_it bank_router bank_mfa_dbo bank_mfa_abs)
for container in "${containers[@]}"; do
  docker exec "$container" sh -ec "date -u +%FT%TZ >/state/.persistence-check"
done

router_hash_before="$(docker exec bank_router sha256sum /state/nftables.conf | awk '{print $1}')"
dbo_hash_before="$(docker exec bank_mfa_dbo sha256sum /state/nginx/nginx.conf /state/authelia/configuration.yml.example | sha256sum | awk '{print $1}')"
abs_hash_before="$(docker exec bank_mfa_abs sha256sum /state/nginx/nginx.conf /state/authelia/configuration.yml.example | sha256sum | awk '{print $1}')"

"${compose[@]}" restart "${containers[@]}" >/dev/null

for container in "${containers[@]}"; do
  status=""
  for _ in {1..36}; do
    status="$(docker inspect --format '{{if .State.Health}}{{.State.Health.Status}}{{else}}{{.State.Status}}{{end}}' "$container" 2>/dev/null || true)"
    [[ "$status" == healthy ]] && break
    sleep 5
  done
  [[ "$status" == healthy ]] || { echo "$container did not become healthy" >&2; exit 1; }
  docker exec "$container" test -s /state/.persistence-check
  docker exec "$container" rm -f /state/.persistence-check
done

router_hash_after="$(docker exec bank_router sha256sum /state/nftables.conf | awk '{print $1}')"
dbo_hash_after="$(docker exec bank_mfa_dbo sha256sum /state/nginx/nginx.conf /state/authelia/configuration.yml.example | sha256sum | awk '{print $1}')"
abs_hash_after="$(docker exec bank_mfa_abs sha256sum /state/nginx/nginx.conf /state/authelia/configuration.yml.example | sha256sum | awk '{print $1}')"
[[ "$router_hash_before" == "$router_hash_after" ]] || { echo "router config changed after restart" >&2; exit 1; }
[[ "$dbo_hash_before" == "$dbo_hash_after" ]] || { echo "DBO MFA config changed after restart" >&2; exit 1; }
[[ "$abs_hash_before" == "$abs_hash_after" ]] || { echo "ABS MFA config changed after restart" >&2; exit 1; }

echo "Persistence verified: router, ARM and both MFA gateway states survived restart."
