FROM banklab/ubuntu-base:1.0

ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update && apt-get install -y --no-install-recommends \
      claws-mail dbus-x11 falkon nmap traceroute wireshark-common \
      xfce4 xfce4-terminal xorgxrdp xrdp && \
    rm -rf /var/lib/apt/lists/* && \
    apt-mark showmanual | sort -u >/usr/share/banklab/base-packages

COPY images/arm-gui/start.sh /usr/local/bin/banklab-arm-start
RUN chmod 0755 /usr/local/bin/banklab-arm-start

EXPOSE 22 3389
ENTRYPOINT ["/usr/local/bin/banklab-arm-start"]
