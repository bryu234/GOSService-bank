#!/usr/bin/env bash
set -euo pipefail
source /usr/local/lib/banklab-common.sh

banklab_require UNTRUSTED_SUBNET DMZ_SUBNET SERVER_SUBNET DATABASE_SUBNET MANAGEMENT_SUBNET \
  VLAN10_OPER_SUBNET VLAN20_CASH_SUBNET VLAN30_ACC_SUBNET VLAN40_IT_SUBNET VPN_POOL \
  BANK_VPN_IP BANK_PROXY_IP PROXY_HTTP_PORT PROXY_HTTPS_PORT

banklab_init_state bank_router
if [[ ! -s /state/nftables.conf ]]; then
  envsubst </defaults/nftables.conf.template >/state/nftables.conf
fi
banklab_start_support /state/nftables.conf

ip route replace "$VPN_POOL" via "$BANK_VPN_IP"
banklab_finish_initialization
echo "bank_router START firewall is active: forwarding is intentionally permissive."
exec sleep infinity
