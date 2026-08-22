#!/usr/bin/env bash
set -euo pipefail
source /usr/local/lib/banklab-common.sh
banklab_init_state bank_backup
banklab_start_support
install -d -m 0750 -o "$LAB_ADMIN_USER" -g "$LAB_ADMIN_USER" /srv/backup
if [[ ! -s /state/backup.conf ]]; then
  printf '%s\n' '# START: shared service identity and broad backup scope are intentionally left for the exercise.' > /state/backup.conf
fi
install -d -m 0755 /etc/bank-backup
ln -sfn /state/backup.conf /etc/bank-backup/backup.conf
banklab_finish_initialization
exec sleep infinity
