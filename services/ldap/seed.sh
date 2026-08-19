#!/usr/bin/env bash
set -euo pipefail

human_dn() { printf 'uid=%s,ou=People,%s' "$1" "$LDAP_BASE_DN"; }
service_dn() { printf 'uid=%s,ou=Services,%s' "$1" "$LDAP_BASE_DN"; }

emit_user() {
  local ou="$1" uid="$2" password="$3" display="$4" hash
  hash="$(slappasswd -s "$password")"
  cat <<EOF
dn: uid=$uid,ou=$ou,$LDAP_BASE_DN
objectClass: inetOrgPerson
uid: $uid
cn: $display
sn: $uid
userPassword: $hash

EOF
}

emit_group() {
  local cn="$1"; shift
  cat <<EOF
dn: cn=$cn,ou=Groups,$LDAP_BASE_DN
objectClass: groupOfNames
cn: $cn
description: Bank Lab role $cn
EOF
  local member
  if (( $# == 0 )); then
    printf 'member: %s\n' "$LDAP_ADMIN_DN"
  else
    for member in "$@"; do printf 'member: %s\n' "$member"; done
  fi
  printf '\n'
}

cat <<EOF
dn: ou=People,$LDAP_BASE_DN
objectClass: organizationalUnit
ou: People

dn: ou=Groups,$LDAP_BASE_DN
objectClass: organizationalUnit
ou: Groups

dn: ou=Services,$LDAP_BASE_DN
objectClass: organizationalUnit
ou: Services

EOF

emit_user People "$OPER_USER" "$OPER_PASSWORD" "Bank Operator"
emit_user People "$CASH_USER" "$CASH_PASSWORD" "Bank Cashier"
emit_user People "$ACC_USER" "$ACC_PASSWORD" "Bank Accountant"
emit_user People "$IT_USER" "$IT_PASSWORD" "Bank IT Specialist"
emit_user Services "$SVC_SHARED_USER" "$SVC_SHARED_PASSWORD" "Shared Service Identity"
emit_user Services "$SVC_ABS_USER" "$SVC_ABS_PASSWORD" "ABS Service Identity"
emit_user Services "$SVC_DBO_USER" "$SVC_DBO_PASSWORD" "DBO Service Identity"
emit_user Services "$SVC_BACKUP_USER" "$SVC_BACKUP_PASSWORD" "Backup Service Identity"
emit_user Services "$SVC_ACC_USER" "$SVC_ACC_PASSWORD" "Accounting Service Identity"

op="$(human_dn "$OPER_USER")"; cash="$(human_dn "$CASH_USER")"; acc="$(human_dn "$ACC_USER")"; it="$(human_dn "$IT_USER")"; shared="$(service_dn "$SVC_SHARED_USER")"
emit_group role_oper "$op"
emit_group role_cash "$cash"
emit_group role_acc "$acc"
emit_group role_it "$it"
emit_group abs_read "$op" "$cash" "$it" "$shared"
emit_group abs_write "$op" "$cash" "$it" "$shared"
emit_group abs_admin "$op" "$it"
emit_group dbo_read "$op" "$it" "$shared"
emit_group dbo_write "$it" "$shared"
emit_group dbo_admin "$it"
emit_group mgmt_read "$it" "$shared"
emit_group mgmt_write "$it" "$shared"
emit_group mgmt_admin "$it"
emit_group acc_read "$cash" "$acc" "$shared"
emit_group acc_write "$acc" "$shared"
emit_group acc_admin
emit_group vpn_users "$it"
emit_group pam_users "$it"
