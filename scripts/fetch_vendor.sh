#!/usr/bin/env bash
set -euo pipefail

root_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
env_file="$root_dir/.env"
[[ -f "$env_file" ]] || env_file="$root_dir/.env.example"
set -a
source "$env_file"
set +a

fetch_commit() {
  local name="$1" repository="$2" commit="$3" destination="$4"
  if [[ -d "$destination/.git" ]]; then
    local current
    current="$(git -C "$destination" rev-parse HEAD)"
    if [[ "$current" == "$commit" ]]; then
      echo "$name already pinned at $commit"
      return
    fi
    echo "$name checkout is $current, expected $commit. Remove $destination explicitly and rerun." >&2
    exit 1
  fi
  mkdir -p "$(dirname "$destination")"
  git init -q "$destination"
  git -C "$destination" remote add origin "$repository"
  git -C "$destination" fetch -q --depth 1 origin "$commit"
  git -C "$destination" checkout -q --detach FETCH_HEAD
  [[ "$(git -C "$destination" rev-parse HEAD)" == "$commit" ]] || { echo "$name commit verification failed" >&2; exit 1; }
  echo "Fetched $name at $commit"
}

fetch_commit "OWASP-101" "$ABS_SOURCE_REPO" "$ABS_SOURCE_COMMIT" "$root_dir/vendor/owasp-101"
fetch_commit "Dolibarr" "$DOLIBARR_SOURCE_REPO" "$DOLIBARR_SOURCE_COMMIT" "$root_dir/vendor/dolibarr"
