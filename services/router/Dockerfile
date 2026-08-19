FROM banklab/ubuntu-base:1.0
RUN apt-get update && apt-get install -y --no-install-recommends conntrack && \
    rm -rf /var/lib/apt/lists/* && apt-mark showmanual | sort -u >/usr/share/banklab/base-packages
COPY services/router/start.sh /usr/local/bin/bank-router-start
COPY services/router/defaults/nftables.conf.template /defaults/nftables.conf.template
RUN chmod 0755 /usr/local/bin/bank-router-start
EXPOSE 22 80 443
ENTRYPOINT ["/usr/local/bin/bank-router-start"]
