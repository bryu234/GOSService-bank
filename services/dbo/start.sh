#!/usr/bin/env bash
set -euo pipefail
source /usr/local/lib/banklab-common.sh

banklab_require DBO_APP_PORT DBO_SECRET_KEY BANK_LDAP_IP LDAP_PORT LDAP_BASE_DN LDAP_BIND_DN LDAP_BIND_PASSWORD
banklab_init_state bank_dbo_web
banklab_start_support

if [[ ! -x /state/venv/bin/python ]]; then
  python3 -m venv --system-site-packages /state/venv
fi
if [[ ! -e /state/mfa.py ]]; then
  cp /opt/banklab/dbo/mfa_disabled.py /state/mfa.py
fi
install -d -m 0750 -o "$LAB_ADMIN_USER" -g "$LAB_ADMIN_USER" /state/audit
banklab_finish_initialization
export PYTHONPATH="/state/venv/lib/python3/dist-packages:/state:${PYTHONPATH:-}"
cd /opt/banklab/dbo
exec /state/venv/bin/python -m gunicorn --bind "0.0.0.0:${DBO_APP_PORT}" --workers 2 --access-logfile /state/audit/access.log app:app
