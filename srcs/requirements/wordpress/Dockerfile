FROM debian:12.7-slim

RUN apt-get update \
 && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
      php-fpm php-mysqli php-cli php-curl php-xml php-zip php-gd php-mbstring \
      curl ca-certificates tzdata less \
 && rm -rf /var/lib/apt/lists/*

# Tune php-fpm pool to listen on TCP:9000 and use env params
COPY conf/www.conf.patch /tmp/www.conf.patch
RUN set -eux; \
    sed -i 's#^;*listen = .*#listen = 9000#' /etc/php/*/fpm/pool.d/www.conf; \
    sed -i 's#^;*pm.max_children = .*#pm.max_children = ${PHP_MAX_CHILDREN:-10}#' /etc/php/*/fpm/pool.d/www.conf

# Entrypoint manages first-run WP setup
COPY tools/wordpress-entrypoint.sh /usr/local/bin/wordpress-entrypoint.sh
RUN chmod +x /usr/local/bin/wordpress-entrypoint.sh

WORKDIR /var/www/html
EXPOSE 9000
ENTRYPOINT ["/usr/local/bin/wordpress-entrypoint.sh"]
CMD ["php-fpm", "-F"]