#!/bin/bash

# Explicitly use bash
set -e

# Check if a database restore script exists
if [[ -f /docker-entrypoint-initdb.d/zz_glpi_restore.sh ]]; then 
    echo "Database restore script found (likely from Podman setup). Skipping restore logic."
else
    # Check if the database exists
    if mysql --host="${MARIADB_DB_HOST}" --user="${MARIADB_DB_USER}" --password="${MARIADB_DB_PASSWORD}" --execute="SHOW DATABASES LIKE '${MARIADB_DB_NAME}';" | grep -q "${MARIADB_DB_NAME}" ; then 
        echo "Database backup found on external database. Restoring..."
        mysqldump --host="${MARIADB_DB_HOST}" --user="${MARIADB_DB_USER}" --password="${MARIADB_DB_PASSWORD}" "${MARIADB_DB_NAME}" | mysql --host=localhost --user="${MARIADB_DB_USER}" --password="${MARIADB_DB_PASSWORD}" "${MARIADB_DB_NAME}" 
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
# Implement Apache configuration based on conditions
#    if [ -f /docker-entrypoint-initdb.d/zz_glpi_restore.sh ]; then
#        echo -e "<VirtualHost *:80>\n\tDocumentRoot /var/www/html/glpi\n\n\t<Directory /var/www/html/glpi>\n\t\tAllowOverride All\n\t\tOrder Allow,Deny\n\t\tAllow from all\n\t</Directory>\n\n\tErrorLog /var/log/apache2/error-glpi.log\n\tLogLevel warn\n\tCustomLog /var/log/apache2/access-glpi.log combined\n</VirtualHost>" > /etc/apache2/sites-available/000-default.conf
#    else
#        echo -e "<VirtualHost *:80>\n\tDocumentRoot /var/www/html/glpi/public\n\n\t<Directory /var/www/html/glpi/public>\n\t\tRequire all granted\n\t\tRewriteEngine On\n\t\tRewriteCond %{REQUEST_FILENAME} !-f\n\t\n\t\tRewriteRule ^(.*)$ index.php [QSA,L]\n\t</Directory>\n\n\tErrorLog /var/log/apache2/error-glpi.log\n\tLogLevel warn\n\tCustomLog /var/log/apache2/access-glpi.log combined\n</VirtualHost>" > /etc/apache2/sites-available/000-default.conf
#    fi
fi
