FROM banklab/ubuntu-base:1.0
RUN apt-get update && apt-get install -y --no-install-recommends openvpn && \
    rm -rf /var/lib/apt/lists/* && apt-mark showmanual | sort -u >/usr/share/banklab/base-packages
COPY services/vpn/start.sh /usr/local/bin/bank-vpn-start
COPY services/vpn/ldap-auth.sh /usr/local/libexec/bank-vpn-ldap-auth
COPY services/vpn/defaults/server.conf.template /defaults/server.conf.template
RUN chmod 0755 /usr/local/bin/bank-vpn-start /usr/local/libexec/bank-vpn-ldap-auth
EXPOSE 22 1194/udp
ENTRYPOINT ["/usr/local/bin/bank-vpn-start"]
