#!/bin/bash

# Explicitly use bash
set -e

if mysql -h"$MARIADB_DB_HOST" -u"$MARIADB_DB_USER" -p"$MARIADB_DB_PASSWORD" -e "USE $MARIADB_DB_NAME;" 2>/dev/null; then
  echo "Database already exists. Skipping setup."
else
  echo "No database backup found. Performing clean install..."
  /usr/bin/php /var/www/html/glpi/bin/console glpi:database:install \
    --reconfigure \
    --no-interaction \
    --force \
    --db-host="$MARIADB_DB_HOST" \
    --db-port="$MARIADB_DB_PORT" \
    --db-name="$MARIADB_DB_NAME" \
    --db-user="$MARIADB_DB_USER" \
    --db-password="$MARIADB_DB_PASSWORD"
fi
