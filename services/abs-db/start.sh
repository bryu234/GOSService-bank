#!/usr/bin/env bash
set -euo pipefail
source /usr/local/lib/banklab-common.sh

banklab_require ABS_DB_PORT ABS_DB_NAME ABS_DB_USER ABS_DB_PASSWORD
banklab_init_state bank_abs_db
banklab_start_support

pgdata=/var/lib/postgresql/16/main
install -d -m 0700 -o postgres -g postgres "$pgdata" /state/postgresql /state/postgresql/log
install -d -m 0755 /etc/postgresql/16/main /var/log/postgresql
if [[ ! -s "$pgdata/PG_VERSION" ]]; then
  runuser -u postgres -- /usr/lib/postgresql/16/bin/initdb -D "$pgdata" --auth-local=trust --auth-host=scram-sha-256
fi
if [[ ! -s /state/postgresql/postgresql.conf ]]; then
  envsubst </defaults/postgresql.conf.template >/state/postgresql/postgresql.conf
fi
if [[ ! -s /state/postgresql/pg_hba.conf ]]; then
  envsubst </defaults/pg_hba.conf.template >/state/postgresql/pg_hba.conf
fi
chown -R postgres:postgres /state/postgresql "$pgdata"
ln -sfn /state/postgresql/postgresql.conf /etc/postgresql/16/main/postgresql.conf
ln -sfn /state/postgresql/pg_hba.conf /etc/postgresql/16/main/pg_hba.conf
rm -rf /var/log/postgresql
ln -sfn /state/postgresql/log /var/log/postgresql

pg_args=(-D "$pgdata" -o "-c config_file=/etc/postgresql/16/main/postgresql.conf -c hba_file=/etc/postgresql/16/main/pg_hba.conf")
if [[ -e /state/.first-boot ]]; then
  runuser -u postgres -- /usr/lib/postgresql/16/bin/pg_ctl "${pg_args[@]}" -w start
  runuser -u postgres -- psql -v ON_ERROR_STOP=1 --set=db_user="$ABS_DB_USER" --set=db_password="$ABS_DB_PASSWORD" --set=db_name="$ABS_DB_NAME" <<'SQL'
SELECT format('CREATE ROLE %I LOGIN PASSWORD %L', :'db_user', :'db_password')
WHERE NOT EXISTS (SELECT FROM pg_roles WHERE rolname = :'db_user')\gexec
SELECT format('CREATE DATABASE %I OWNER %I', :'db_name', :'db_user')
WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = :'db_name')\gexec
SQL
  runuser -u postgres -- /usr/lib/postgresql/16/bin/pg_ctl "${pg_args[@]}" -m fast -w stop
fi

banklab_finish_initialization
exec runuser -u postgres -- /usr/lib/postgresql/16/bin/postgres -D "$pgdata" \
  -c config_file=/etc/postgresql/16/main/postgresql.conf -c hba_file=/etc/postgresql/16/main/pg_hba.conf
