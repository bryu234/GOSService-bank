FROM banklab/ubuntu-base:1.0
RUN apt-get update && apt-get install -y --no-install-recommends gunicorn python3-flask python3-ldap && \
    rm -rf /var/lib/apt/lists/* && apt-mark showmanual | sort -u >/usr/share/banklab/base-packages
COPY services/dbo/app /opt/banklab/dbo
COPY services/dbo/start.sh /usr/local/bin/bank-dbo-start
RUN chmod 0755 /usr/local/bin/bank-dbo-start
EXPOSE 22 8082
ENTRYPOINT ["/usr/local/bin/bank-dbo-start"]
