FROM banklab/ubuntu-base:1.0
RUN apt-get update && apt-get install -y --no-install-recommends postgresql-client-16 rsync && \
    rm -rf /var/lib/apt/lists/* && apt-mark showmanual | sort -u >/usr/share/banklab/base-packages
COPY services/admin/start.sh /usr/local/bin/bank-admin-start
RUN chmod 0755 /usr/local/bin/bank-admin-start
EXPOSE 22
ENTRYPOINT ["/usr/local/bin/bank-admin-start"]
