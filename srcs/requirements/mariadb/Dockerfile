FROM debian:12.7-slim

RUN apt-get update \
 && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
      mariadb-server mariadb-client ca-certificates tzdata \
 && rm -rf /var/lib/apt/lists/*

# Tweak basic server config via a small cnf include
COPY conf/mariadb.cnf /etc/mysql/mariadb.conf.d/99-inception.cnf

# Entrypoint script handles first-run init safely
COPY tools/mariadb-entrypoint.sh /usr/local/bin/mariadb-entrypoint.sh
RUN chmod +x /usr/local/bin/mariadb-entrypoint.sh

EXPOSE 3306
ENTRYPOINT ["/usr/local/bin/mariadb-entrypoint.sh"]
CMD ["mariadbd", "--user=mysql", "--bind-address=0.0.0.0"]