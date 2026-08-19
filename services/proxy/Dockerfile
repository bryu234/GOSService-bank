FROM banklab/ubuntu-base:1.0
RUN apt-get update && apt-get install -y --no-install-recommends nginx && \
    rm -rf /var/lib/apt/lists/* && apt-mark showmanual | sort -u >/usr/share/banklab/base-packages
COPY services/proxy/start.sh /usr/local/bin/bank-proxy-start
COPY services/proxy/defaults/nginx.conf.template /defaults/nginx.conf.template
RUN chmod 0755 /usr/local/bin/bank-proxy-start
EXPOSE 22 80 443
ENTRYPOINT ["/usr/local/bin/bank-proxy-start"]
