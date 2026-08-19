FROM banklab/ubuntu-base:1.0
RUN apt-get update && apt-get install -y --no-install-recommends postgresql-16 postgresql-client-16 && \
    rm -rf /var/lib/apt/lists/* && apt-mark showmanual | sort -u >/usr/share/banklab/base-packages
COPY services/abs-db/start.sh /usr/local/bin/bank-abs-db-start
COPY services/abs-db/defaults/postgresql.conf.template /defaults/postgresql.conf.template
COPY services/abs-db/defaults/pg_hba.conf.template /defaults/pg_hba.conf.template
RUN chmod 0755 /usr/local/bin/bank-abs-db-start
EXPOSE 22 5432
ENTRYPOINT ["/usr/local/bin/bank-abs-db-start"]
