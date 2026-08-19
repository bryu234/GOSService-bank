FROM banklab/ubuntu-base:1.0
RUN apt-get update && apt-get install -y --no-install-recommends \
      build-essential libldap2-dev libpq-dev libsasl2-dev python3-dev python3-pip && \
    rm -rf /var/lib/apt/lists/* && apt-mark showmanual | sort -u >/usr/share/banklab/base-packages

COPY vendor/owasp-101/python /opt/banklab/abs
COPY services/abs/overlay/ /opt/banklab/abs/
RUN mkdir -p /opt/banklab/wheels && \
    python3 -m pip wheel --wheel-dir /opt/banklab/wheels -r /opt/banklab/abs/requirements.lock

COPY services/abs/start.sh /usr/local/bin/bank-abs-start
RUN chmod 0755 /usr/local/bin/bank-abs-start
EXPOSE 22 8080
ENTRYPOINT ["/usr/local/bin/bank-abs-start"]
