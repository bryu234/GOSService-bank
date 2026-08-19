#!/usr/bin/env bash
set -euo pipefail
source /usr/local/lib/banklab-common.sh

banklab_require ACC_APP_PORT ACC_DB_NAME ACC_DB_USER ACC_DB_PASSWORD ACC_ADMIN_USER ACC_ADMIN_PASSWORD
banklab_require BANK_LDAP_IP LDAP_PORT LDAP_BASE_DN LDAP_ADMIN_DN LDAP_ADMIN_PASSWORD
banklab_init_state bank_acc_sys
banklab_start_support

pgdata=/var/lib/postgresql/16/main
install -d -m 0700 -o postgres -g postgres "$pgdata"
install -d -m 0750 -o www-data -g www-data /state/dolibarr /state/apache /var/lib/dolibarr/documents
install -d -m 0750 -o postgres -g postgres /state/postgresql

if [[ ! -s "$pgdata/PG_VERSION" ]]; then
  runuser -u postgres -- /usr/lib/postgresql/16/bin/initdb -D "$pgdata" --auth-local=trust --auth-host=scram-sha-256
fi

if [[ ! -e /state/postgresql.conf ]]; then
  cat >/state/postgresql.conf <<'EOF'
listen_addresses = '127.0.0.1'
port = 5432
max_connections = 100
shared_buffers = 128MB
logging_collector = on
log_directory = '/state/postgresql'
log_filename = 'postgresql.log'
EOF
fi
if [[ ! -e /state/postgresql/pg_hba.conf ]]; then
  cat >/state/postgresql/pg_hba.conf <<'EOF'
local all all trust
host all all 127.0.0.1/32 scram-sha-256
host all all ::1/128 scram-sha-256
EOF
fi
chown postgres:postgres /state/postgresql.conf /state/postgresql/pg_hba.conf "$pgdata"

pg_args=(-D "$pgdata" -o "-c config_file=/state/postgresql.conf -c hba_file=/state/postgresql/pg_hba.conf")
runuser -u postgres -- /usr/lib/postgresql/16/bin/pg_ctl "${pg_args[@]}" -w start

if [[ -e /state/.first-boot ]]; then
  runuser -u postgres -- psql -v ON_ERROR_STOP=1 \
    --set=db_user="$ACC_DB_USER" --set=db_password="$ACC_DB_PASSWORD" --set=db_name="$ACC_DB_NAME" <<'SQL'
SELECT format('CREATE ROLE %I LOGIN PASSWORD %L', :'db_user', :'db_password')
WHERE NOT EXISTS (SELECT FROM pg_roles WHERE rolname = :'db_user')\gexec
SELECT format('CREATE DATABASE %I OWNER %I', :'db_name', :'db_user')
WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = :'db_name')\gexec
SQL
fi

if [[ ! -e /state/dolibarr/htdocs/index.php ]]; then
  cp -a /opt/banklab/dolibarr/htdocs /state/dolibarr/
  cp -a /opt/banklab/dolibarr/scripts /state/dolibarr/
fi
install -m 0640 -o www-data -g www-data /opt/banklab/install.forced.php /state/dolibarr/htdocs/install/install.forced.php
chown -R www-data:www-data /state/dolibarr /var/lib/dolibarr/documents /state/apache

if [[ ! -e /state/.dolibarr-installed ]]; then
  # Dolibarr's CLI installer refuses to generate its configuration unless the
  # target exists and is writable by the web user.  Keep it in /state so a
  # container recreation resumes safely after an interrupted first boot.
  install -d -m 0750 -o www-data -g www-data /state/dolibarr/htdocs/conf
  install -m 0660 -o www-data -g www-data /dev/null /state/dolibarr/htdocs/conf/conf.php
  cd /state/dolibarr/htdocs/install
  runuser -u www-data -- php step1.php set ru_RU \
    /state/dolibarr/htdocs /var/lib/dolibarr/documents \
    "http://accounting.bank.lab:${ACC_APP_PORT}" postgres '' pgsql 127.0.0.1 \
    "$ACC_DB_NAME" "$ACC_DB_USER" "$ACC_DB_PASSWORD" 5432 llx_ 0 0
  runuser -u www-data -- php step2.php set ru_RU
  runuser -u www-data -- php step5.php '' '' ru_RU set \
    "$ACC_ADMIN_USER" "$ACC_ADMIN_PASSWORD" "$ACC_ADMIN_PASSWORD" 1

  conf=/state/dolibarr/htdocs/conf/conf.php
  sed -i "s/\$dolibarr_main_authentication='dolibarr';/\$dolibarr_main_authentication='ldap,dolibarr';/" "$conf"
  cat >>"$conf" <<'PHP'

// Bank Lab START: LDAP is deliberately broad and MFA is not enabled.
$dolibarr_main_auth_ldap_host='ldap://'.getenv('BANK_LDAP_IP');
$dolibarr_main_auth_ldap_port=getenv('LDAP_PORT');
$dolibarr_main_auth_ldap_version='3';
$dolibarr_main_auth_ldap_servertype='openldap';
$dolibarr_main_auth_ldap_login_attribute='uid';
$dolibarr_main_auth_ldap_dn=getenv('LDAP_BASE_DN');
$dolibarr_main_auth_ldap_filter='(uid=%1%)';
$dolibarr_main_auth_ldap_admin_login=getenv('LDAP_ADMIN_DN');
$dolibarr_main_auth_ldap_admin_pass=getenv('LDAP_ADMIN_PASSWORD');
PHP
  chown www-data:www-data "$conf"
  chmod 0640 "$conf"
  touch /state/.dolibarr-installed
fi

# Dolibarr 23 uses the single-argument ldap_connect() form on PHP 8.3+, so a
# persisted host must be a full LDAP URI.  Migrate configurations created by
# earlier lab images before Apache starts.
conf=/state/dolibarr/htdocs/conf/conf.php
sed -i "s#^\$dolibarr_main_auth_ldap_host=getenv('BANK_LDAP_IP');#\$dolibarr_main_auth_ldap_host='ldap://'.getenv('BANK_LDAP_IP');#" "$conf"

envsubst </defaults/accounting-apache.conf.template >/state/apache/accounting.conf
ln -sf /state/apache/accounting.conf /etc/apache2/sites-enabled/000-default.conf

/usr/local/bin/bank-accounting-sync-ldap || true
(
  while sleep 60; do
    /usr/local/bin/bank-accounting-sync-ldap >>/state/ldap-sync.log 2>&1 || true
  done
) &

banklab_finish_initialization
exec apachectl -D FOREGROUND
