ARG UBUNTU_VERSION=24.04
FROM ubuntu:${UBUNTU_VERSION}

ENV DEBIAN_FRONTEND=noninteractive TZ=Etc/UTC LANG=C.UTF-8

RUN apt-get update && apt-get install -y --no-install-recommends \
      bash ca-certificates curl dnsutils gettext-base iproute2 iputils-ping jq less locales \
      ldap-utils nano net-tools netcat-openbsd nftables openssh-client openssh-server openssl \
      procps python3 python3-venv rsyslog sudo tcpdump tzdata vim wget && \
    rm -rf /var/lib/apt/lists/* && \
    if id ubuntu >/dev/null 2>&1; then userdel --remove ubuntu; fi && \
    mkdir -p /run/sshd /state /usr/share/banklab && \
    apt-mark showmanual | sort -u >/usr/share/banklab/base-packages

COPY images/ubuntu-base/banklab-common.sh /usr/local/lib/banklab-common.sh
COPY images/ubuntu-base/banklab-record-packages /usr/local/sbin/banklab-record-packages
COPY images/ubuntu-base/banklab-save-routes /usr/local/sbin/banklab-save-routes
COPY images/ubuntu-base/banklab-save-firewall /usr/local/sbin/banklab-save-firewall
COPY images/ubuntu-base/99banklab-persist /etc/apt/apt.conf.d/99banklab-persist
RUN chmod 0755 /usr/local/lib/banklab-common.sh /usr/local/sbin/banklab-* && \
    printf '%s\n' 'table inet banklab_host {' ' chain input { type filter hook input priority 0; policy accept; }' ' chain forward { type filter hook forward priority 0; policy accept; }' ' chain output { type filter hook output priority 0; policy accept; }' '}' >/usr/share/banklab/default-nftables.conf

EXPOSE 22
