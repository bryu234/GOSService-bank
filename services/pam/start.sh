#!/usr/bin/env bash
set -euo pipefail
source /usr/local/lib/banklab-common.sh

banklab_init_state bank_pam
banklab_start_support
install -d -m 0750 /state/pam /state/tlog
if [[ ! -s /state/pam/sshd ]]; then
  cp /etc/pam.d/sshd /state/pam/sshd
fi
ln -sfn /state/pam/sshd /etc/pam.d/sshd
if [[ -f /etc/nslcd.conf && ! -s /state/pam/nslcd.conf ]]; then
  cp /etc/nslcd.conf /state/pam/nslcd.conf
fi
[[ ! -e /state/pam/nslcd.conf ]] || ln -sfn /state/pam/nslcd.conf /etc/nslcd.conf
banklab_finish_initialization
echo "bank_pam is optional in START; MFA and mandatory session recording are intentionally disabled."
exec sleep infinity
