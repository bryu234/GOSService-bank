#!/usr/bin/env bash
set -euo pipefail
source /usr/local/lib/banklab-common.sh

banklab_require VPN_POOL VPN_PORT BANK_LDAP_IP LDAP_BASE_DN LDAP_BIND_DN LDAP_BIND_PASSWORD
banklab_init_state bank_vpn
banklab_start_support

vpn_dir=/state/openvpn
install -d -m 0700 "$vpn_dir"
if [[ ! -s "$vpn_dir/ca.crt" ]]; then
  openssl req -x509 -newkey rsa:3072 -nodes -days 3650 -subj '/CN=Bank Lab VPN CA' \
    -keyout "$vpn_dir/ca.key" -out "$vpn_dir/ca.crt"
  openssl req -newkey rsa:3072 -nodes -subj '/CN=bank_vpn' -keyout "$vpn_dir/server.key" -out "$vpn_dir/server.csr"
  openssl x509 -req -days 1825 -in "$vpn_dir/server.csr" -CA "$vpn_dir/ca.crt" -CAkey "$vpn_dir/ca.key" \
    -CAcreateserial -out "$vpn_dir/server.crt"
  openssl req -newkey rsa:3072 -nodes -subj '/CN=banklab-client' -keyout "$vpn_dir/client.key" -out "$vpn_dir/client.csr"
  openssl x509 -req -days 1825 -in "$vpn_dir/client.csr" -CA "$vpn_dir/ca.crt" -CAkey "$vpn_dir/ca.key" \
    -CAcreateserial -out "$vpn_dir/client.crt"
  openvpn --genkey secret "$vpn_dir/tls-crypt.key"
fi

read -r vpn_network vpn_netmask < <(python3 - "$VPN_POOL" <<'PY'
import ipaddress, sys
n = ipaddress.ip_network(sys.argv[1])
print(n.network_address, n.netmask)
PY
)

if [[ ! -s "$vpn_dir/server.conf" ]]; then
  export VPN_NETWORK="$vpn_network" VPN_NETMASK="$vpn_netmask"
  envsubst </defaults/server.conf.template >"$vpn_dir/server.conf"
fi

if [[ ! -s "$vpn_dir/client.ovpn" ]]; then
  cat >"$vpn_dir/client.ovpn" <<EOF
client
dev tun
proto udp
remote <VM_IP> ${VPN_HOST_PORT}
nobind
auth-user-pass
remote-cert-tls server
<ca>
$(cat "$vpn_dir/ca.crt")
</ca>
<cert>
$(cat "$vpn_dir/client.crt")
</cert>
<key>
$(cat "$vpn_dir/client.key")
</key>
<tls-crypt>
$(cat "$vpn_dir/tls-crypt.key")
</tls-crypt>
EOF
  chmod 0600 "$vpn_dir/client.ovpn"
fi

banklab_finish_initialization
exec openvpn --config "$vpn_dir/server.conf"
