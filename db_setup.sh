#!/bin/bash

# Explicitly use bash
set -e
chown -R www-data:www-data /var/www/html/glpi/
chmod -R u+rwx /var/www/html/glpi/
# Check if a database restore script exists
if [[ -f /docker-entrypoint-initdb.d/zz_glpi_restore.sh ]]; then 
    echo "Database restore script found (likely from Podman setup). Skipping restore logic."
else
    # Check if the database exists
    if mysql --host="${MARIADB_DB_HOST}" --user="${MARIADB_DB_USER}" --password="${MARIADB_DB_PASSWORD}" --execute="SHOW DATABASES LIKE '${MARIADB_DB_NAME}';" | grep -q "${MARIADB_DB_NAME}" ; then 
        echo "Database backup found on external database. Restoring..."
#       mysqldump --host="${MARIADB_DB_HOST}" --user="${MARIADB_DB_USER}" --password="${MARIADB_DB_PASSWORD}" --socket="/var/run/mysqld/mysqld.sock" "${MARIADB_DB_NAME}" | mysql --host=localhost --user="${MARIADB_DB_USER}" --password="${MARIADB_DB_PASSWORD}" --socket="/var/run/mysqld/mysqld.sock" "${MARIADB_DB_NAME}"
          /usr/bin/php /var/www/html/glpi/bin/console glpi:database:install \
                      --reconfigure \
                      --no-interaction \
                      --db-host="${MARIADB_DB_HOST}" \
                      --db-port="${MARIADB_DB_PORT}" \
                      --db-name="${MARIADB_DB_NAME}" \
                      --db-user="${MARIADB_DB_USER}" \
                      --db-password="${MARIADB_DB_PASSWORD}"
    else
        echo "No database backup found. Performing clean install..."
        /usr/bin/php /var/www/html/glpi/bin/console glpi:database:install \
              --reconfigure \
              --no-interaction \
              --force \
              --db-host="${MARIADB_DB_HOST}" \
              --db-port="${MARIADB_DB_PORT}" \
              --db-name="${MARIADB_DB_NAME}" \
              --db-user="${MARIADB_DB_USER}" \
              --db-password="${MARIADB_DB_PASSWORD}" 
    fi
fi
