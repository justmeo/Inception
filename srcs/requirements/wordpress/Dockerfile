FROM debian:12.7-slim

RUN apt-get update \
 && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
      php-fpm php-mysqli php-cli php-curl php-xml php-zip php-gd php-mbstring \
      curl ca-certificates tzdata less \
 && rm -rf /var/lib/apt/lists/*

# Configure PHP-FPM to listen on port 9000 only (pm.max_children set at runtime)
RUN sed -i 's#^;*listen = .*#listen = 9000#' /etc/php/*/fpm/pool.d/www.conf

# Entrypoint manages first-run WP setup
COPY tools/wordpress-entrypoint.sh /usr/local/bin/wordpress-entrypoint.sh
RUN chmod +x /usr/local/bin/wordpress-entrypoint.sh

WORKDIR /var/www/html
EXPOSE 9000
ENTRYPOINT ["/usr/local/bin/wordpress-entrypoint.sh"]
CMD ["php-fpm", "-F"]