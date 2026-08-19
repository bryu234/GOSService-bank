FROM banklab/ubuntu-base:1.0
RUN apt-get update && apt-get install -y --no-install-recommends rsync postgresql-client-16 && \
    rm -rf /var/lib/apt/lists/* && apt-mark showmanual | sort -u >/usr/share/banklab/base-packages
COPY services/backup/start.sh /usr/local/bin/bank-backup-start
RUN chmod 0755 /usr/local/bin/bank-backup-start
EXPOSE 22
ENTRYPOINT ["/usr/local/bin/bank-backup-start"]
