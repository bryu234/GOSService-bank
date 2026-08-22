#!/usr/bin/env bash
set -euo pipefail

export PGPASSWORD="$ACC_DB_PASSWORD"
psql -h 127.0.0.1 -U "$ACC_DB_USER" -d "$ACC_DB_NAME" -v ON_ERROR_STOP=1 \
  --set=ldap_host="$BANK_LDAP_IP" --set=ldap_port="$LDAP_PORT" \
  --set=ldap_admin_dn="$LDAP_ADMIN_DN" --set=ldap_admin_pass="$LDAP_ADMIN_PASSWORD" \
  --set=ldap_base_dn="$LDAP_BASE_DN" <<'SQL'
DELETE FROM llx_const WHERE entity = 1 AND name IN (
  'LDAP_SERVER_HOST','LDAP_SERVER_PORT','LDAP_SERVER_TYPE','LDAP_SERVER_PROTOCOLVERSION',
  'LDAP_SERVER_PROTOCOL_VERSION','LDAP_SERVER_DN',
  'LDAP_ADMIN_DN','LDAP_ADMIN_PASS','LDAP_USER_DN','LDAP_GROUP_DN','LDAP_KEY_USERS',
  'LDAP_KEY_GROUPS','LDAP_FIELD_LOGIN','LDAP_FIELD_FULLNAME','LDAP_FIELD_NAME',
  'LDAP_FIELD_FIRSTNAME','LDAP_FIELD_MAIL','LDAP_GROUP_FIELD_FULLNAME',
  'LDAP_GROUP_FIELD_DESCRIPTION','LDAP_GROUP_FIELD_GROUPMEMBERS','LDAP_FILTER_CONNECTION',
  'LDAP_GROUP_FILTER'
);
INSERT INTO llx_const (name, entity, value, type, visible) VALUES
  ('LDAP_SERVER_HOST',1,'ldap://' || :'ldap_host','string',0),
  ('LDAP_SERVER_PORT',1,:'ldap_port','string',0),
  ('LDAP_SERVER_TYPE',1,'openldap','string',0),
  ('LDAP_SERVER_PROTOCOLVERSION',1,'3','string',0),
  ('LDAP_SERVER_DN',1,:'ldap_base_dn','string',0),
  ('LDAP_ADMIN_DN',1,:'ldap_admin_dn','string',0),
  ('LDAP_ADMIN_PASS',1,:'ldap_admin_pass','string',0),
  ('LDAP_USER_DN',1,:'ldap_base_dn','string',0),
  ('LDAP_GROUP_DN',1,'ou=Groups,' || :'ldap_base_dn','string',0),
  ('LDAP_KEY_USERS',1,'uid','string',0),
  ('LDAP_KEY_GROUPS',1,'cn','string',0),
  ('LDAP_FIELD_LOGIN',1,'uid','string',0),
  ('LDAP_FIELD_FULLNAME',1,'cn','string',0),
  ('LDAP_FIELD_NAME',1,'sn','string',0),
  ('LDAP_FIELD_FIRSTNAME',1,'cn','string',0),
  ('LDAP_FIELD_MAIL',1,'mail','string',0),
  ('LDAP_GROUP_FIELD_FULLNAME',1,'cn','string',0),
  ('LDAP_GROUP_FIELD_DESCRIPTION',1,'description','string',0),
  ('LDAP_GROUP_FIELD_GROUPMEMBERS',1,'member','string',0),
  ('LDAP_FILTER_CONNECTION',1,'objectClass=inetOrgPerson','string',0),
  ('LDAP_GROUP_FILTER',1,'objectClass=groupOfNames','string',0);
SQL

php /var/www/dolibarr/scripts/user/sync_users_ldap2dolibarr.php nocommitiferror -y
php /var/www/dolibarr/scripts/user/sync_groups_ldap2dolibarr.php nocommitiferror -y

psql -h 127.0.0.1 -U "$ACC_DB_USER" -d "$ACC_DB_NAME" -v ON_ERROR_STOP=1 <<'SQL'
DELETE FROM llx_usergroup_rights ugr
USING llx_usergroup ug
WHERE ugr.fk_usergroup = ug.rowid AND ug.nom IN ('acc_read', 'acc_write');

INSERT INTO llx_usergroup_rights (entity, fk_usergroup, fk_id)
SELECT 1, ug.rowid, rd.id
FROM llx_usergroup ug
CROSS JOIN llx_rights_def rd
WHERE ug.nom = 'acc_read' AND rd.entity = 1
  AND (rd.perms IN ('lire', 'read') OR rd.subperms IN ('lire', 'read'));

INSERT INTO llx_usergroup_rights (entity, fk_usergroup, fk_id)
SELECT 1, ug.rowid, rd.id
FROM llx_usergroup ug
CROSS JOIN llx_rights_def rd
WHERE ug.nom = 'acc_write' AND rd.entity = 1
  AND lower(coalesce(rd.perms, '') || ' ' || coalesce(rd.subperms, ''))
      !~ '(delete|remove|supprimer|effacer|admin|setup|config)';
SQL
