#!/usr/bin/env bash
set -euo pipefail
source /usr/local/lib/banklab-common.sh

banklab_require ABS_APP_PORT ABS_DB_NAME ABS_DB_USER ABS_DB_PASSWORD BANK_ABS_DB_IP ABS_DB_PORT \
  ABS_DJANGO_SECRET BANK_LDAP_IP LDAP_PORT LDAP_BASE_DN LDAP_BIND_DN LDAP_BIND_PASSWORD
banklab_init_state bank_abs
banklab_start_support

if [[ ! -d /state/app/bac ]]; then
  mkdir -p /state/app
  cp -a /opt/banklab/abs/. /state/app/
fi
if [[ ! -x /state/venv/bin/python ]]; then
  python3 -m venv /state/venv
  /state/venv/bin/pip install --no-index --find-links /opt/banklab/wheels -r /state/app/requirements.lock
fi
if [[ ! -e /state/app/bac/mfa.py ]]; then
  cp /state/app/bac/mfa_disabled.py /state/app/bac/mfa.py
fi

cd /state/app
/state/venv/bin/python manage.py migrate --noinput
/state/venv/bin/python manage.py seed_banklab
/state/venv/bin/python manage.py collectstatic --noinput >/dev/null
banklab_finish_initialization
exec /state/venv/bin/gunicorn --bind "0.0.0.0:${ABS_APP_PORT}" --workers 2 bac.wsgi:application
