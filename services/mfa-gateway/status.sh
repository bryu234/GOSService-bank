#!/usr/bin/env bash
set -euo pipefail

if [[ -e /state/authelia/enabled ]]; then
  echo "persistent: enabled"
else
  echo "persistent: START bypass"
fi
if [[ -s /run/authelia.pid ]] && kill -0 "$(cat /run/authelia.pid)" 2>/dev/null; then
  echo "authelia: running"
else
  echo "authelia: stopped"
fi
if grep -Eq '^[[:space:]]*include[[:space:]]+/etc/nginx/snippets/authelia-authrequest\.conf;' /etc/nginx/nginx.conf; then
  echo "nginx auth_request: enabled"
else
  echo "nginx auth_request: disabled"
fi
