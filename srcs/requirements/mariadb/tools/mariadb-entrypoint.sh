#!/usr/bin/env bash
set -euo pipefail

# Load secrets
DB_ROOT_PASSWORD=$(cat /run/secrets/db_root_password)
DB_PASSWORD=$(cat /run/secrets/db_password)

MYSQL_DATABASE=${MYSQL_DATABASE:-wordpress}
MYSQL_USER=${MYSQL_USER:-wp_user}

DATA_DIR="/var/lib/mysql"
SOCKET="/run/mysqld/mysqld.sock"

mkdir -p /run/mysqld
chown -R mysql:mysql /run/mysqld "$DATA_DIR"

# Initialize database if missing
if [ ! -d "$DATA_DIR/mysql" ]; then
  echo "[MariaDB] Initializing data directory..."
  mariadb-install-db --user=mysql --datadir="$DATA_DIR" --auth-root-authentication-method=socket >/dev/null

  # Start temp server
  mysqld --user=mysql --skip-networking --socket="$SOCKET" &
  pid=$!
  for i in {30..0}; do
    mariadb-admin --socket="$SOCKET" ping &>/dev/null && break
    echo "[MariaDB] Waiting for server... $i"; sleep 1
  done

  if ! mariadb-admin --socket="$SOCKET" ping &>/dev/null; then
    echo "[MariaDB] Failed to start temp server"; exit 1
  fi

  echo "[MariaDB] Securing and creating database/user"
  mariadb --socket="$SOCKET" <<-SQL
    -- Set root password and keep root local-only via unix socket
    ALTER USER 'root'@'localhost' IDENTIFIED BY '${DB_ROOT_PASSWORD}';

    -- Create app database and user
    CREATE DATABASE IF NOT EXISTS \`${MYSQL_DATABASE}\` DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
    CREATE USER IF NOT EXISTS \`${MYSQL_USER}\`@'%' IDENTIFIED BY '${DB_PASSWORD}';
    GRANT ALL PRIVILEGES ON \`${MYSQL_DATABASE}\`.* TO \`${MYSQL_USER}\`@'%';
    FLUSH PRIVILEGES;
SQL

  mariadb-admin --socket="$SOCKET" shutdown
  wait "$pid"
fi

# Exec real server in foreground (PID 1)
exec "$@"