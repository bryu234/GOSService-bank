#!/usr/bin/env bash
set -euo pipefail

env_file="${1:-.env}"
compose=(docker compose --env-file "$env_file" -f compose.yaml)
marker="/state/.persistence-check"

docker exec bank_arm_it sh -ec "date -u +%FT%TZ >'$marker'"
router_hash_before="$(docker exec bank_router sha256sum /state/nftables.conf | awk '{print $1}')"

"${compose[@]}" restart bank_arm_it bank_router >/dev/null

status=""
for _ in {1..36}; do
  status="$(docker inspect --format '{{if .State.Health}}{{.State.Health.Status}}{{else}}{{.State.Status}}{{end}}' bank_arm_it 2>/dev/null || true)"
  [[ "$status" == healthy ]] && break
  sleep 5
done
[[ "$status" == healthy ]] || { echo "bank_arm_it did not become healthy" >&2; exit 1; }

docker exec bank_arm_it test -s "$marker"
router_hash_after="$(docker exec bank_router sha256sum /state/nftables.conf | awk '{print $1}')"
[[ "$router_hash_before" == "$router_hash_after" ]] || { echo "router config changed after restart" >&2; exit 1; }
docker exec bank_arm_it rm -f "$marker"

echo "Persistence verified: state volume and router policy survived container restart."
