FROM debian:12.5

LABEL org.opencontainers.image.authors="github@genius.ke"
ENV DEBIAN_FRONTEND noninteractive

# Update package lists and install common dependencies
RUN apt-get update && apt-get install -y \
    ca-certificates \
    apt-transport-https \
    lsb-release \
    wget \
    curl \
    jq \
    software-properties-common \
    cron \
    mariadb-client # For database interaction

# Add sury.org PHP repository and key
RUN apt-get update \
    && apt-get install -y ca-certificates apt-transport-https lsb-release wget curl \
    && curl -sSLo /usr/share/keyrings/deb.sury.org-php.gpg https://packages.sury.org/php/apt.gpg \
    && sh -c 'echo "deb [signed-by=/usr/share/keyrings/deb.sury.org-php.gpg] https://packages.sury.org/php/ $(lsb_release -sc) main" > /etc/apt/sources.list.d/php.list'

# Update package lists again after adding repository
RUN apt-get update

# Install PHP and its extensions
RUN apt-get install -y \
    php8.1 \
    php8.1-common \
    php8.1-mysql \
    php8.1-ldap \
    php8.1-xmlrpc \
    php8.1-imap \
    php8.1-curl \
    php8.1-gd \
    php8.1-mbstring \
    php8.1-xml \
    php-cas \
    php8.1-intl \
    php8.1-zip \
    php8.1-bz2 \
    php8.1-redis

# Install Apache and set up config
RUN apt-get install -y apache2 

# Download GLPI
ARG GLPI_VERSION=10.0.14 # Default version
RUN wget -qO /tmp/glpi-${GLPI_VERSION}.tgz https://github.com/glpi-project/glpi/releases/download/${GLPI_VERSION}/glpi-${GLPI_VERSION}.tgz && \
    tar -xzf /tmp/glpi-${GLPI_VERSION}.tgz -C /var/www/html/ && \
    rm /tmp/glpi-${GLPI_VERSION}.tgz

# GLPI Version Handling - Use sed to modify Apache configuration
RUN sed -i 's#/var/www/html/glpi/public#/var/www/html/glpi#g' /etc/apache2/sites-available/000-default.conf

# PHP configuration modifications
RUN echo "memory_limit = 64M ;" > /etc/php/8.1/apache2/conf.d/99-glpi.ini && \
    echo "file_uploads = on ;" >> /etc/php/8.1/apache2/conf.d/99-glpi.ini && \
    echo "max_execution_time = 600 ;" >> /etc/php/8.1/apache2/conf.d/99-glpi.ini && \
    echo "register_globals = off ;" >> /etc/php/8.1/apache2/conf.d/99-glpi.ini && \
    echo "magic_quotes_sybase = off ;" >> /etc/php/8.1/apache2/conf.d/99-glpi.ini && \
    echo "session.auto_start = off ;" >> /etc/php/8.1/apache2/conf.d/99-glpi.ini && \
    echo "session.use_trans_sid = 0 ;" >> /etc/php/8.1/apache2/conf.d/99-glpi.ini && \
    echo "apc.enable_cli = 1 ;" > /etc/php/8.1/mods-available/apcu.ini

# Set permissions and configurations for GLPI
RUN chown -R www-data:www-data /var/www/html/glpi && \
    chmod -R u+rwx /var/www/html/glpi

# Database setup script
#COPY db_setup.sh /tmp/

# Debugging output
#RUN ls -l /tmp  

# Execute the database setup script
#RUN chmod +x /tmp/db_setup.sh \
#    && /tmp/db_setup.sh
# GLPI database setup
RUN if [[ -f /docker-entrypoint-initdb.d/zz_glpi_restore.sh ]]; then \
        echo "Database restore script found (likely from Podman setup). Skipping restore logic."; \
    else \
        if mysql --host="${MARIADB_DB_HOST}" --user="${MARIADB_DB_USER}" --password="${MARIADB_DB_PASSWORD}" --execute="SHOW DATABASES LIKE '${MARIADB_DB_NAME}';" | grep -q "${MARIADB_DB_NAME}" ; then \
            echo "Database backup found on external database. Restoring..."; \
            mysqldump --host="${MARIADB_DB_HOST}" --user="${MARIADB_DB_USER}" --password="${MARIADB_DB_PASSWORD}" "${MARIADB_DB_NAME}" | mysql --host=localhost --user="${MARIADB_DB_USER}" --password="${MARIADB_DB_PASSWORD}" "${MARIADB_DB_NAME}"; \
        else \
            echo "No database backup found. Performing clean install..."; \
            /usr/bin/php /var/www/html/glpi/bin/console glpi:database:install \
                --reconfigure \
                --no-interaction \
                --force \
                --db-host="${MARIADB_DB_HOST}" \
                --db-port="${MARIADB_DB_PORT}" \
                --db-name="${MARIADB_DB_NAME}" \
                --db-user="${MARIADB_DB_USER}" \
                --db-password="${MARIADB_DB_PASSWORD}"; \
        fi; \
    fi

# Expose ports, start Apache
EXPOSE 80 443
CMD ["apachectl", "-D", "FOREGROUND"]
