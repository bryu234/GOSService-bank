FROM banklab/ubuntu-base:1.0

ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update && apt-get install -y --no-install-recommends \
      apache2 libapache2-mod-php php php-bcmath php-curl php-gd php-intl \
      php-ldap php-mbstring php-pgsql php-xml php-zip postgresql-16 \
      postgresql-client-16 && \
    a2enmod rewrite headers expires && \
    rm -rf /var/lib/apt/lists/* && \
    apt-mark showmanual | sort -u >/usr/share/banklab/base-packages

COPY vendor/dolibarr/htdocs /opt/banklab/dolibarr/htdocs
COPY vendor/dolibarr/scripts /opt/banklab/dolibarr/scripts
COPY services/accounting/apache.conf.template /defaults/accounting-apache.conf.template
COPY services/accounting/install.forced.php /opt/banklab/install.forced.php
COPY services/accounting/start.sh /usr/local/bin/bank-accounting-start
COPY services/accounting/sync-ldap.sh /usr/local/bin/bank-accounting-sync-ldap
RUN chmod 0755 /usr/local/bin/bank-accounting-start /usr/local/bin/bank-accounting-sync-ldap

EXPOSE 22 8081
ENTRYPOINT ["/usr/local/bin/bank-accounting-start"]
