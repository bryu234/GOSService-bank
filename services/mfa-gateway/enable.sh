#!/usr/bin/env bash
set -euo pipefail

/usr/local/sbin/banklab-mfa-validate
/usr/local/sbin/banklab-mfa-launch
touch /state/authelia/enabled
nginx -s reload
echo "MFA gateway is enabled and will remain enabled after restart."
