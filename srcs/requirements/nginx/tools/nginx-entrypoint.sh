#!/usr/bin/env bash
set -euo pipefail

DOMAIN=${DOMAIN_NAME}
SSL_DIR=/etc/nginx/ssl
mkdir -p "$SSL_DIR"

CRT="$SSL_DIR/${DOMAIN}.crt"
KEY="$SSL_DIR/${DOMAIN}.key"

# Generate self-signed cert if missing
if [ ! -f "$CRT" ] || [ ! -f "$KEY" ]; then
  echo "[NGINX] Generating self-signed certificate for ${DOMAIN}"
  openssl req -x509 -nodes -newkey rsa:4096 -days 365 \
    -keyout "$KEY" -out "$CRT" \
    -subj "/CN=${DOMAIN}"
fi

# Write server block: expand ${CRT}/${KEY}, but keep NGINX $vars by escaping $
cat >/etc/nginx/conf.d/inception.conf <<NGX
server {
    listen 443 ssl http2;
    server_name ${DOMAIN};

    ssl_certificate     ${CRT};
    ssl_certificate_key ${KEY};
    ssl_protocols       TLSv1.2 TLSv1.3;
    ssl_prefer_server_ciphers on;
    ssl_ciphers 'ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384:ECDHE-ECDSA-CHACHA20-POLY1305:ECDHE-RSA-CHACHA20-POLY1305:ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256';
    ssl_dhparam /etc/nginx/dhparam.pem;
    add_header Strict-Transport-Security "max-age=31536000; includeSubDomains" always;

    root /var/www/html;
    index index.php index.html;

    # Deny .git etc.
    location ~ /\. { deny all; }

    # PHP via php-fpm (WordPress container)
    location ~ \.php$ {
        include fastcgi_params;
        fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
        fastcgi_pass wordpress:9000;
    }

    location / {
        try_files \$uri \$uri/ /index.php?\$args;
    }
}
NGX

rm -f /etc/nginx/sites-enabled/default || true
nginx -t
exec "$@"