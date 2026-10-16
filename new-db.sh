#!/usr/bin/env bash
NAME="${1:?usage: ./new-db.sh <name>}"
[[ "$NAME" =~ ^[a-z0-9_]+$ ]] || { echo "name must match [a-z0-9_]+"; exit 1; }

cd "$(dirname "$0")"
set -a; source .env; set +a

PASS="$(openssl rand -base64 36 | tr -dc 'A-Za-z0-9' | cut -c1-24)"

docker compose exec -T -e MYSQL_PWD="$DB_ROOT_PASS" db mysql -uroot <<SQL
CREATE DATABASE IF NOT EXISTS \`${NAME}\` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE USER IF NOT EXISTS '${NAME}'@'%' IDENTIFIED BY '${PASS}';
ALTER USER '${NAME}'@'%' IDENTIFIED BY '${PASS}';
GRANT ALL PRIVILEGES ON \`${NAME}\`.* TO '${NAME}'@'%';
FLUSH PRIVILEGES;
SQL

echo
echo "DB_HOST=db"
echo "DB_NAME=${NAME}"
echo "DB_USER=${NAME}"
echo "DB_PASS=${PASS}"