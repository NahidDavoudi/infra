#!/usr/bin/env bash
# بکاپ روزانه: هر دیتابیس جدا + پوشه uploads هر اپ + کپی بیرون سرور (اختیاری)
# کرون: 30 3 * * * /opt/infra/backup.sh >> /var/log/backup.log 2>&1
set -euo pipefail

cd /opt/infra
set -a; source .env; set +a

BACKUP_DIR=/opt/backups
KEEP_DAYS=7
DATE="$(date +%F_%H%M)"
mkdir -p "$BACKUP_DIR/db" "$BACKUP_DIR/uploads"

dbx() { docker compose exec -T -e MYSQL_PWD="$DB_ROOT_PASS" db "$@"; }

# --- دیتابیس‌ها ---
DBS="$(dbx mariadb -uroot -N -e 'SHOW DATABASES' | tr -d '\r' | grep -Ev '^(information_schema|performance_schema|mysql|sys)$')"
for db in $DBS; do
  out="$BACKUP_DIR/db/${db}_${DATE}.sql.gz"
  if dbx mariadb-dump -uroot --single-transaction --routines --events "$db" | gzip > "$out"; then
    echo "OK  db: $db"
  else
    rm -f "$out"; echo "FAIL db: $db" >&2
  fi
done

# --- آپلودها ---
for dir in /opt/apps/*/uploads; do
  [ -d "$dir" ] || continue
  app="$(basename "$(dirname "$dir")")"
  tar -czf "$BACKUP_DIR/uploads/${app}_${DATE}.tar.gz" -C "$dir" .
  echo "OK  uploads: $app"
done

# --- پاکسازی قدیمی‌ها ---
find "$BACKUP_DIR" -type f -mtime +"$KEEP_DAYS" -delete

# --- کپی بیرون از سرور ---
if [ -n "${BACKUP_REMOTE:-}" ]; then
  rsync -az "$BACKUP_DIR/" "$BACKUP_REMOTE"
  echo "OK  rsync -> $BACKUP_REMOTE"
fi

