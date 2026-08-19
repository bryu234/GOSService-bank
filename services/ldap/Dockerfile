FROM banklab/ubuntu-base:1.0
RUN apt-get update && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends slapd && \
    rm -rf /var/lib/apt/lists/* && apt-mark showmanual | sort -u >/usr/share/banklab/base-packages
COPY services/ldap/start.sh /usr/local/bin/bank-ldap-start
COPY services/ldap/seed.sh /usr/local/libexec/bank-ldap-seed
RUN chmod 0755 /usr/local/bin/bank-ldap-start /usr/local/libexec/bank-ldap-seed
EXPOSE 22 389 636
ENTRYPOINT ["/usr/local/bin/bank-ldap-start"]
