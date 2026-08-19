#!/usr/bin/env bash
set -euo pipefail
source /usr/local/lib/banklab-common.sh

banklab_require VPN_POOL VPN_PORT BANK_LDAP_IP LDAP_PORT LDAP_BASE_DN
banklab_init_state bank_vpn
banklab_start_support

vpn_dir=/state/openvpn
install -d -m 0700 "$vpn_dir"
if [[ ! -s "$vpn_dir/ca.crt" ]]; then
  openssl req -x509 -newkey rsa:3072 -nodes -days 3650 -subj '/CN=Bank Lab VPN CA' \
    -keyout "$vpn_dir/ca.key" -out "$vpn_dir/ca.crt"
fi
if [[ ! -s "$vpn_dir/tls-crypt.key" ]]; then
  openvpn --genkey secret "$vpn_dir/tls-crypt.key"
fi

cert_has_eku() {
  [[ -s "$1" ]] && [[ "$(openssl x509 -in "$1" -noout -text 2>/dev/null)" == *"$2"* ]]
}

refresh_client=0
if ! cert_has_eku "$vpn_dir/server.crt" 'TLS Web Server Authentication'; then
  [[ -s "$vpn_dir/server.key" ]] || openssl genpkey -algorithm RSA -pkeyopt rsa_keygen_bits:3072 -out "$vpn_dir/server.key"
  openssl req -new -key "$vpn_dir/server.key" -subj '/CN=bank_vpn' -out "$vpn_dir/server.csr"
  openssl x509 -req -days 1825 -in "$vpn_dir/server.csr" -CA "$vpn_dir/ca.crt" -CAkey "$vpn_dir/ca.key" \
    -CAcreateserial -out "$vpn_dir/server.crt" -extfile <(printf '%s\n' \
      'basicConstraints=CA:FALSE' 'keyUsage=digitalSignature,keyEncipherment' \
      'extendedKeyUsage=serverAuth' 'subjectAltName=DNS:bank_vpn')
fi
if ! cert_has_eku "$vpn_dir/client.crt" 'TLS Web Client Authentication'; then
  [[ -s "$vpn_dir/client.key" ]] || openssl genpkey -algorithm RSA -pkeyopt rsa_keygen_bits:3072 -out "$vpn_dir/client.key"
  openssl req -new -key "$vpn_dir/client.key" -subj '/CN=banklab-client' -out "$vpn_dir/client.csr"
  openssl x509 -req -days 1825 -in "$vpn_dir/client.csr" -CA "$vpn_dir/ca.crt" -CAkey "$vpn_dir/ca.key" \
    -CAcreateserial -out "$vpn_dir/client.crt" -extfile <(printf '%s\n' \
      'basicConstraints=CA:FALSE' 'keyUsage=digitalSignature,keyEncipherment' \
      'extendedKeyUsage=clientAuth')
  refresh_client=1
fi

read -r vpn_network vpn_netmask < <(python3 - "$VPN_POOL" <<'PY'
import ipaddress, sys
n = ipaddress.ip_network(sys.argv[1])
print(n.network_address, n.netmask)
PY
)

export_route_parts() {
  local prefix="$1" subnet="$2" network netmask
  read -r network netmask < <(python3 - "$subnet" <<'PY'
import ipaddress, sys
n = ipaddress.ip_network(sys.argv[1])
print(n.network_address, n.netmask)
PY
  )
  printf -v "${prefix}_NETWORK" %s "$network"
  printf -v "${prefix}_NETMASK" %s "$netmask"
  export "${prefix}_NETWORK" "${prefix}_NETMASK"
}

export_route_parts DMZ "$DMZ_SUBNET"
export_route_parts SERVER "$SERVER_SUBNET"
export_route_parts DATABASE "$DATABASE_SUBNET"
export_route_parts MANAGEMENT "$MANAGEMENT_SUBNET"
export_route_parts VLAN10_OPER "$VLAN10_OPER_SUBNET"
export_route_parts VLAN20_CASH "$VLAN20_CASH_SUBNET"
export_route_parts VLAN30_ACC "$VLAN30_ACC_SUBNET"
export_route_parts VLAN40_IT "$VLAN40_IT_SUBNET"

if [[ ! -s "$vpn_dir/server.conf" ]]; then
  export VPN_NETWORK="$vpn_network" VPN_NETMASK="$vpn_netmask"
  envsubst </defaults/server.conf.template >"$vpn_dir/server.conf"
fi

migrate_route() {
  local prefix="$1" subnet="$2" network_var="${1}_NETWORK" netmask_var="${1}_NETMASK"
  sed -i "s#^push \"route ${subnet}\"\$#push \"route ${!network_var} ${!netmask_var}\"#" "$vpn_dir/server.conf"
}

migrate_route DMZ "$DMZ_SUBNET"
migrate_route SERVER "$SERVER_SUBNET"
migrate_route DATABASE "$DATABASE_SUBNET"
migrate_route MANAGEMENT "$MANAGEMENT_SUBNET"
migrate_route VLAN10_OPER "$VLAN10_OPER_SUBNET"
migrate_route VLAN20_CASH "$VLAN20_CASH_SUBNET"
migrate_route VLAN30_ACC "$VLAN30_ACC_SUBNET"
migrate_route VLAN40_IT "$VLAN40_IT_SUBNET"

while IFS='=' read -r name value; do
  grep -q "^setenv ${name} " "$vpn_dir/server.conf" || printf 'setenv %s %s\n' "$name" "$value" >>"$vpn_dir/server.conf"
done <<EOF
BANK_LDAP_IP=$BANK_LDAP_IP
LDAP_PORT=$LDAP_PORT
LDAP_BASE_DN=$LDAP_BASE_DN
EOF

if [[ ! -s "$vpn_dir/client.ovpn" || "$refresh_client" = 1 ]]; then
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
