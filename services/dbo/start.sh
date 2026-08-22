#!/usr/bin/env bash
set -euo pipefail
source /usr/local/lib/banklab-common.sh

banklab_require DBO_APP_PORT DBO_SECRET_KEY BANK_LDAP_IP LDAP_PORT LDAP_BASE_DN LDAP_BIND_DN LDAP_BIND_PASSWORD
banklab_init_state bank_dbo_web
banklab_start_support

if [[ ! -x /state/venv/bin/python ]]; then
  python3 -m venv --system-site-packages /state/venv
fi
install -d -m 0750 -o "$LAB_ADMIN_USER" -g "$LAB_ADMIN_USER" /state/audit
rm -rf /opt/banklab/venv /var/log/bank-dbo
ln -sfn /state/venv /opt/banklab/venv
ln -sfn /state/audit /var/log/bank-dbo
banklab_finish_initialization
export PYTHONPATH="/opt/banklab/venv/lib/python3/dist-packages:/opt/banklab/dbo:${PYTHONPATH:-}"
cd /opt/banklab/dbo
exec /opt/banklab/venv/bin/python -m gunicorn --bind "0.0.0.0:${DBO_APP_PORT}" --workers 2 --access-logfile /var/log/bank-dbo/access.log app:app
