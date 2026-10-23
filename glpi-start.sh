#!/bin/bash
#
# Container entrypoint: deploys the GLPI release shipped in the image into the
# volume /var/www/html/glpi, installs or updates the database and starts
# Apache in the foreground.
#
# Environment: MARIADB_DB_HOST, MARIADB_DB_PORT, MARIADB_DB_NAME,
# MARIADB_DB_USER, MARIADB_DB_PASSWORD (first installation only), TIMEZONE.
# VERSION_GLPI is ignored: the GLPI version is the one bundled in the image.

set -e

FOLDER_SRC=/usr/src/glpi
FOLDER_GLPI=/var/www/html/glpi
# Kept across upgrades, see https://glpi-install.readthedocs.io/en/latest/update.html
KEEP_ON_UPGRADE="config files marketplace plugins"

console() {
	runuser -u www-data -- /usr/bin/php "${FOLDER_GLPI}/bin/console" --no-interaction "$@"
}

## Setup PHP
if [[ -z "${TIMEZONE}" ]]; then
	echo "TIMEZONE is unset"
else
	echo "date.timezone = \"$TIMEZONE\"" >/etc/php/8.3/apache2/conf.d/timezone.ini
	echo "date.timezone = \"$TIMEZONE\"" >/etc/php/8.3/cli/conf.d/timezone.ini
fi

#check if TLS_REQCERT is present
if !(grep -q "TLS_REQCERT" /etc/ldap/ldap.conf); then
	echo "TLS_REQCERT isn't present"
	echo -e "TLS_REQCERT\tnever" >>/etc/ldap/ldap.conf
fi

## Deploy the bundled GLPI release into the volume
BUNDLED_VERSION=$(ls "${FOLDER_SRC}/version")
INSTALLED_VERSION=$(ls "${FOLDER_GLPI}/version" 2>/dev/null || true)
mkdir -p "${FOLDER_GLPI}"

if [[ -z "${INSTALLED_VERSION}" ]]; then
	echo "Deploying GLPI ${BUNDLED_VERSION}"
	cp -a "${FOLDER_SRC}/." "${FOLDER_GLPI}/"
elif [[ "${INSTALLED_VERSION}" == "${BUNDLED_VERSION}" ]]; then
	echo "GLPI ${INSTALLED_VERSION} is already deployed"
elif [[ "$(printf '%s\n' "${INSTALLED_VERSION}" "${BUNDLED_VERSION}" | sort -V | tail -n 1)" == "${BUNDLED_VERSION}" ]]; then
	echo "Upgrading GLPI ${INSTALLED_VERSION} to ${BUNDLED_VERSION}"
	for entry in "${FOLDER_GLPI}"/* "${FOLDER_GLPI}"/.[!.]*; do
		[[ -e "${entry}" ]] || continue
		[[ " ${KEEP_ON_UPGRADE} " == *" $(basename "${entry}") "* ]] && continue
		rm -rf "${entry}"
	done
	cp -a "${FOLDER_SRC}/." "${FOLDER_GLPI}/"
else
	echo "GLPI ${INSTALLED_VERSION} in the volume is newer than ${BUNDLED_VERSION} in the image; downgrade is not supported" >&2
	exit 1
fi
chown -R www-data:www-data "${FOLDER_GLPI}"

#Adapt the Apache server to GLPI >= 10 (document root is public/)
set +H
echo -e "<VirtualHost *:80>
    DocumentRoot /var/www/html/glpi/public

    <Directory /var/www/html/glpi/public>
        Require all granted

        RewriteEngine On

        # Ensure authorization headers are passed to PHP.
        RewriteCond %{HTTP:Authorization} ^(.+)$
        RewriteRule .* - [E=HTTP_AUTHORIZATION:%{HTTP:Authorization}]

        # Redirect all requests to GLPI router, unless file exists.
        RewriteCond %{REQUEST_FILENAME} !-f
        RewriteRule ^(.*)$ index.php [QSA,L]
    </Directory>

    ErrorLog /var/log/apache2/error-glpi.log
    LogLevel warn
    CustomLog /var/log/apache2/access-glpi.log combined
</VirtualHost>" >/etc/apache2/sites-available/000-default.conf

## Database: install once, afterwards only update.
# Never run "database:install --force" on an existing instance: it recreates
# all glpi_* tables (data loss) and replaces the encryption key.
if [[ ! -f "${FOLDER_GLPI}/config/config_db.php" ]]; then
	console glpi:database:install \
		--db-host="${MARIADB_DB_HOST}" \
		--db-port="${MARIADB_DB_PORT}" \
		--db-name="${MARIADB_DB_NAME}" \
		--db-user="${MARIADB_DB_USER}" \
		--db-password="${MARIADB_DB_PASSWORD}"
else
	console glpi:database:update
fi

# Enable time zones (needs read access to the mysql time zone tables; optional)
console database:enable_timezones || echo "Time zones not enabled, see the message above"

#Add scheduled task by cron and enable
echo "*/2 * * * * www-data /usr/bin/php /var/www/html/glpi/front/cron.php &>/dev/null" >/etc/cron.d/glpi
#Start cron service
service cron start

#Activation du module rewrite d'apache
a2enmod rewrite

#Lancement du service apache au premier plan
exec /usr/sbin/apache2ctl -D FOREGROUND
