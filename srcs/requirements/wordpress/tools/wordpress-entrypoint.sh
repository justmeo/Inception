#!/usr/bin/env bash
set -euo pipefail

DB_HOST="mariadb"
DB_NAME=${MYSQL_DATABASE:-wordpress}
DB_USER=${MYSQL_USER:-wp_user}
DB_PASSWORD=$(cat /run/secrets/db_password)
SITE_URL="https://${DOMAIN_NAME}"

# --- Runtime PHP-FPM tuning (fixes pm.max_children error) ---
PHP_CHILDREN="${PHP_MAX_CHILDREN:-10}"
if ! [[ "$PHP_CHILDREN" =~ ^[0-9]+$ ]] || [ "$PHP_CHILDREN" -le 0 ]; then
  PHP_CHILDREN=10
fi
sed -i "s#^;*pm.max_children = .*#pm.max_children = ${PHP_CHILDREN}#" /etc/php/*/fpm/pool.d/www.conf
sed -i 's#^;*listen = .*#listen = 9000#' /etc/php/*/fpm/pool.d/www.conf

# Ensure docroot exists and ownership is correct
mkdir -p /var/www/html
chown -R www-data:www-data /var/www

# Wait for DB (bounded retries)
for i in {1..30}; do
  if php -r "@mysqli_connect('${DB_HOST}','${DB_USER}','${DB_PASSWORD}','${DB_NAME}') ?: exit(1);"; then
    echo "[WP] Database is reachable"; break
  fi
  echo "[WP] Waiting for DB... ($i/30)"; sleep 1
  if [ "$i" -eq 30 ]; then echo "[WP] DB not reachable, aborting"; exit 1; fi
done

# Install wp-cli locally
if ! command -v wp >/dev/null 2>&1; then
  curl -sSL https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar -o /usr/local/bin/wp
  chmod +x /usr/local/bin/wp
fi

# Download WordPress on first run
if [ ! -f wp-load.php ]; then
  echo "[WP] Downloading WordPress core..."
  wp core download --path=/var/www/html --allow-root
fi

# Create config if missing
if [ ! -f wp-config.php ]; then
  echo "[WP] Creating wp-config.php"
  cat > wp-config.php << EOF
<?php
define('DB_NAME', '${DB_NAME}');
define('DB_USER', '${DB_USER}');
define('DB_PASSWORD', '${DB_PASSWORD}');
define('DB_HOST', '${DB_HOST}');
define('DB_CHARSET', 'utf8');
define('DB_COLLATE', '');
define('AUTH_KEY',         'put your unique phrase here');
define('SECURE_AUTH_KEY',  'put your unique phrase here');
define('LOGGED_IN_KEY',    'put your unique phrase here');
define('NONCE_KEY',        'put your unique phrase here');
define('AUTH_SALT',        'put your unique phrase here');
define('SECURE_AUTH_SALT', 'put your unique phrase here');
define('LOGGED_IN_SALT',   'put your unique phrase here');
define('NONCE_SALT',       'put your unique phrase here');
\$table_prefix = 'wp_';
define('WP_DEBUG', false);
if (!defined('ABSPATH')) {
    define('ABSPATH', __DIR__ . '/');
}
require_once ABSPATH . 'wp-settings.php';
EOF
else
  echo "[WP] Updating existing wp-config.php with correct password"
  sed -i "s/define( 'DB_PASSWORD', '.*' );/define( 'DB_PASSWORD', '${DB_PASSWORD}' );/" wp-config.php
fi

# Install site if not installed
if ! wp core is-installed --allow-root 2>/dev/null; then
  echo "[WP] Installing site at ${SITE_URL}"
  wp core install \
    --url="${SITE_URL}" \
    --title="${WP_TITLE:-Inception}" \
    --admin_user="${WP_ADMIN_USER}" \
    --admin_password=$(cat /run/secrets/db_root_password) \
    --admin_email="${WP_ADMIN_EMAIL}" \
    --skip-email \
    --allow-root 2>/dev/null || echo "[WP] Site installation failed, but continuing..."

  # Create an extra non-admin user
  if [[ -n "${WP_USER:-}" && -n "${WP_USER_EMAIL:-}" ]]; then
    wp user create "$WP_USER" "$WP_USER_EMAIL" --role=author --user_pass=$(cat /run/secrets/db_password) --allow-root 2>/dev/null || echo "[WP] User creation failed, but continuing..."
  fi
fi

# Permissions (secure): owner www-data, no world write
chown -R www-data:www-data /var/www/html
find /var/www/html -type d -exec chmod 755 {} \;
find /var/www/html -type f -exec chmod 644 {} \;

# Exec php-fpm in foreground (PID 1); handle versioned binary
if command -v php-fpm >/dev/null 2>&1; then
  exec php-fpm -F
else
  exec php-fpm8.2 -F
fi
