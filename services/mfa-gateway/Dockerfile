FROM banklab/ubuntu-base:1.0

ARG AUTHELIA_VERSION=4.39.20
ARG TARGETARCH
ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y --no-install-recommends nginx && \
    rm -rf /var/lib/apt/lists/* && \
    apt-mark showmanual | sort -u >/usr/share/banklab/base-packages

RUN set -eux; \
    arch="${TARGETARCH:-$(dpkg --print-architecture)}"; \
    case "$arch" in \
      amd64) checksum='1f122add61752d6ef54e64ae7116bec4e026f5c0a6493498288c5a9770d92088' ;; \
      arm64) checksum='39088706d58609cfcd43db6d72b88cc106c535390759accbce51adf4ece639d8' ;; \
      *) echo "Unsupported Authelia architecture: $arch" >&2; exit 1 ;; \
    esac; \
    archive="authelia-v${AUTHELIA_VERSION}-linux-${arch}.tar.gz"; \
    curl -fsSLo "/tmp/$archive" "https://github.com/authelia/authelia/releases/download/v${AUTHELIA_VERSION}/$archive"; \
    echo "$checksum  /tmp/$archive" | sha256sum -c -; \
    tar -xzf "/tmp/$archive" -C /tmp authelia; \
    install -m 0755 /tmp/authelia /usr/local/bin/authelia; \
    rm -f "/tmp/$archive" /tmp/authelia

COPY services/mfa-gateway/defaults /defaults
COPY services/mfa-gateway/start.sh /usr/local/bin/bank-mfa-gateway-start
COPY services/mfa-gateway/launch.sh /usr/local/sbin/banklab-mfa-launch
COPY services/mfa-gateway/validate.sh /usr/local/sbin/banklab-mfa-validate
COPY services/mfa-gateway/enable.sh /usr/local/sbin/banklab-mfa-enable
COPY services/mfa-gateway/status.sh /usr/local/sbin/banklab-mfa-status
RUN chmod 0755 /usr/local/bin/bank-mfa-gateway-start /usr/local/sbin/banklab-mfa-* && \
    nginx -V 2>&1 | grep -q -- '--with-http_auth_request_module'

EXPOSE 22 80 443 9091
ENTRYPOINT ["/usr/local/bin/bank-mfa-gateway-start"]
