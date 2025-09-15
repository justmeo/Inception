#!/usr/bin/env bash
set -euo pipefail

DB_HOST="mariadb"
DB_NAME=${MYSQL_DATABASE:-wordpress}
DB_USER=${MYSQL_USER:-wp_user}
DB_PASSWORD=$(cat /run/secrets/db_password)
SITE_URL="https://${DOMAIN_NAME}"

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
  sudo -u www-data wp core download --path=/var/www/html --allow-root
fi

# Create config if missing
if [ ! -f wp-config.php ]; then
  echo "[WP] Creating wp-config.php"
  sudo -u www-data wp config create \
    --dbname="$DB_NAME" \
    --dbuser="$DB_USER" \
    --dbpass="$DB_PASSWORD" \
    --dbhost="$DB_HOST" \
    --dbprefix=wp_ \
    --skip-check \
    --allow-root
fi

# Install site if not installed
if ! sudo -u www-data wp core is-installed --allow-root; then
  echo "[WP] Installing site at ${SITE_URL}"
  sudo -u www-data wp core install \
    --url="${SITE_URL}" \
    --title="${WP_TITLE:-Inception}" \
    --admin_user="${WP_ADMIN_USER}" \
    --admin_password=$(cat /run/secrets/db_root_password) \
    --admin_email="${WP_ADMIN_EMAIL}" \
    --skip-email \
    --allow-root

  # Create a non-admin user for content
  if [[ -n "${WP_USER:-}" && -n "${WP_USER_EMAIL:-}" ]]; then
    sudo -u www-data wp user create "$WP_USER" "$WP_USER_EMAIL" --role=author --user_pass=$(cat /run/secrets/db_password) --allow-root || true
  fi
fi

# Permissions (secure): owner www-data, no world write
chown -R www-data:www-data /var/www/html
find /var/www/html -type d -exec chmod 755 {} \;
find /var/www/html -type f -exec chmod 644 {} \;

# Exec php-fpm in foreground (PID 1)
exec "$@"