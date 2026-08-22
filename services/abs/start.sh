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
if [[ ! -e /state/.migration-web-mfa-gateway-v1 ]]; then
  sed -i '/bac\.mfa_middleware\.BankLabMfaMiddleware/d' /state/app/bac/settings.py
  touch /state/.migration-web-mfa-gateway-v1
fi
rm -rf /opt/banklab/abs-live /opt/banklab/venv
ln -sfn /state/app /opt/banklab/abs-live
ln -sfn /state/venv /opt/banklab/venv

cd /opt/banklab/abs-live
/opt/banklab/venv/bin/python manage.py migrate --noinput
/opt/banklab/venv/bin/python manage.py seed_banklab
/opt/banklab/venv/bin/python manage.py collectstatic --noinput >/dev/null
banklab_finish_initialization
exec /opt/banklab/venv/bin/gunicorn --bind "0.0.0.0:${ABS_APP_PORT}" --workers 2 bac.wsgi:application
