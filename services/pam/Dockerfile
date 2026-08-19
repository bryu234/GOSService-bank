FROM banklab/ubuntu-base:1.0
RUN apt-get update && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
      libnss-ldapd libpam-ldapd nslcd tlog && \
    rm -rf /var/lib/apt/lists/* && apt-mark showmanual | sort -u >/usr/share/banklab/base-packages
COPY services/pam/start.sh /usr/local/bin/bank-pam-start
RUN chmod 0755 /usr/local/bin/bank-pam-start
EXPOSE 22
ENTRYPOINT ["/usr/local/bin/bank-pam-start"]
