#!/usr/bin/env bash
set -euo pipefail
source /usr/local/lib/banklab-common.sh

banklab_require UNTRUSTED_SUBNET DMZ_SUBNET SERVER_SUBNET DATABASE_SUBNET MANAGEMENT_SUBNET \
  VLAN10_OPER_SUBNET VLAN20_CASH_SUBNET VLAN30_ACC_SUBNET VLAN40_IT_SUBNET VPN_POOL \
  BANK_VPN_IP BANK_PROXY_IP PROXY_HTTP_PORT PROXY_HTTPS_PORT SSH_PORT RDP_PORT \
  BANK_ARM_OPER_IP BANK_ARM_CASH_IP BANK_ARM_ACC_IP BANK_ARM_IT_IP \
  ARM_OPER_HOST_SSH_PORT ARM_CASH_HOST_SSH_PORT ARM_ACC_HOST_SSH_PORT ARM_IT_HOST_SSH_PORT \
  ARM_OPER_HOST_RDP_PORT ARM_CASH_HOST_RDP_PORT ARM_ACC_HOST_RDP_PORT ARM_IT_HOST_RDP_PORT

banklab_init_state bank_router
if [[ ! -s /state/nftables.conf ]]; then
  envsubst </defaults/nftables.conf.template >/state/nftables.conf
fi

if [[ ! -e /state/.migration-arm-host-ports-v1 ]]; then
  rules=(
    "    tcp dport ${ARM_OPER_HOST_SSH_PORT} dnat to ${BANK_ARM_OPER_IP}:${SSH_PORT}"
    "    tcp dport ${ARM_CASH_HOST_SSH_PORT} dnat to ${BANK_ARM_CASH_IP}:${SSH_PORT}"
    "    tcp dport ${ARM_ACC_HOST_SSH_PORT} dnat to ${BANK_ARM_ACC_IP}:${SSH_PORT}"
    "    tcp dport ${ARM_IT_HOST_SSH_PORT} dnat to ${BANK_ARM_IT_IP}:${SSH_PORT}"
    "    tcp dport ${ARM_OPER_HOST_RDP_PORT} dnat to ${BANK_ARM_OPER_IP}:${RDP_PORT}"
    "    tcp dport ${ARM_CASH_HOST_RDP_PORT} dnat to ${BANK_ARM_CASH_IP}:${RDP_PORT}"
    "    tcp dport ${ARM_ACC_HOST_RDP_PORT} dnat to ${BANK_ARM_ACC_IP}:${RDP_PORT}"
    "    tcp dport ${ARM_IT_HOST_RDP_PORT} dnat to ${BANK_ARM_IT_IP}:${RDP_PORT}"
  )
  for rule in "${rules[@]}"; do
    grep -Fqx "$rule" /state/nftables.conf || \
      sed -i "/tcp dport ${PROXY_HTTPS_PORT} dnat to/a\\$rule" /state/nftables.conf
  done
  touch /state/.migration-arm-host-ports-v1
fi
banklab_start_support /state/nftables.conf

ip route replace "$VPN_POOL" via "$BANK_VPN_IP"
banklab_finish_initialization
echo "bank_router START firewall is active: forwarding is intentionally permissive."
exec sleep infinity
