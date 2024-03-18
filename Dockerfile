# Choose a Debian base image
FROM debian:12.0

# Set author label
LABEL org.opencontainers.image.authors="github@genius.ke"

# Set non-interactive environment
ENV DEBIAN_FRONTEND noninteractive

# Update package repositories
RUN apt-get update

# Install necessary packages in smaller groups
RUN apt-get install -y \
    ca-certificates \
    apt-transport-https \
    lsb-release \
    wget \
    curl \
    jq

RUN apt-get install -y \
    cron \
    apache2 \
    php8.1 \
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

RUN apt-get install -y \
    libldap-2.4-2 \
    libldap-common \
    libsasl2-2 \
    libsasl2-modules \
    libsasl2-modules-db

#    && \
#    rm -rf /var/lib/apt/lists/*

# Add PHP repository and key
#RUN wget -O /etc/apt/trusted.gpg.d/php.gpg https://packages.sury.org/php/apt.gpg && \
#    echo "deb https://packages.sury.org/php/ $(lsb_release -sc) main" > /etc/apt/sources.list.d/php.list && \
#    apt-get update

# Set up PHP configurations
RUN echo "memory_limit = 64M ;" > /etc/php/8.1/apache2/conf.d/99-glpi.ini && \
    echo "file_uploads = on ;" >> /etc/php/8.1/apache2/conf.d/99-glpi.ini && \
    echo "max_execution_time = 600 ;" >> /etc/php/8.1/apache2/conf.d/99-glpi.ini && \
    echo "register_globals = off ;" >> /etc/php/8.1/apache2/conf.d/99-glpi.ini && \
    echo "magic_quotes_sybase = off ;" >> /etc/php/8.1/apache2/conf.d/99-glpi.ini && \
    echo "session.auto_start = off ;" >> /etc/php/8.1/apache2/conf.d/99-glpi.ini && \
    echo "session.use_trans_sid = 0 ;" >> /etc/php/8.1/apache2/conf.d/99-glpi.ini && \
    echo "apc.enable_cli = 1 ;" > /etc/php/8.1/mods-available/apcu.ini

# Set up Apache virtual hosts
RUN echo -e "<VirtualHost *:80>\n\tDocumentRoot /var/www/html/glpi\n\n\t<Directory /var/www/html/glpi>\n\t\tAllowOverride All\n\t\tOrder Allow,Deny\n\t\tAllow from all\n\t</Directory>\n\n\tErrorLog /var/log/apache2/error-glpi.log\n\tLogLevel warn\n\tCustomLog /var/log/apache2/access-glpi.log combined\n</VirtualHost>" > /etc/apache2/sites-available/000-default.conf

# Set permissions and configurations for GLPI
RUN mkdir -p /var/www/html/glpi && \
    chown -R www-data:www-data /var/www/html/glpi && \
    chmod -R u+rwx /var/www/html/glpi

# Copy GLPI installation script
#COPY install_glpi.sh /usr/local/bin/install_glpi.sh
#RUN chmod +x /usr/local/bin/install_glpi.sh

# Expose ports
EXPOSE 80 443

# Start Apache server
CMD ["apachectl", "-D", "FOREGROUND"]

# Script for GLPI installation and initialization
RUN \
    LOGS="install_glpi.log" && \
    echo "====================================================" >> $LOGS && \
    echo "## VARIABLES" >> $LOGS && \
    echo "====================================================" >> $LOGS && \
    echo "Remove old PHP..." && \
    yum -y remove \
        php-cli \
        mod_php \
        php-common && \
    echo "Install ..." && \
    yum -y install \
        mod_php \
        php-cli \
        php-mysqlnd \
        php-pear-CAS \
        wget \
        php-json \
        php-mbstring \
        php-mysqli \
        php-session \
        php-gd \
        php-curl \
        php-domxml \
        php-imap \
        php-ldap \
        php-openssl \
        php-opcache \
        php-apcu \
        php-xmlrpc \
        php-intl \
        php-zip \
        php-sodium \
        jq \
        openssl && \
    echo "Setting 99-glpi.ini..." && \
    echo "memory_limit = 64M ;" > /etc/php.d/99-glpi.ini && \
    echo "file_uploads = on ;" >> /etc/php.d/99-glpi.ini && \
    echo "max_execution_time = 600 ;" >> /etc/php.d/99-glpi.ini && \
    echo "register_globals = off ;" >> /etc/php.d/99-glpi.ini && \
    echo "magic_quotes_sybase = off ;" >> /etc/php.d/99-glpi.ini && \
    echo "session.auto_start = off ;" >> /etc/php.d/99-glpi.ini && \
    echo "session.use_trans_sid = 0 ;" >> /etc/php.d/99-glpi.ini && \
    echo "apc.enable_cli = 1 ;" > /etc/php.d/99-apcu.ini && \
    [[ ! "$VERSION_GLPI" ]] && \
    VERSION_GLPI=$(curl -s https://api.github.com/repos/glpi-project/glpi/releases/latest | grep tag_name | cut -d '"' -f 4) && \
    if [[ -z "${TIMEZONE}" ]]; then \
        echo "TIMEZONE is unset"; \
    else \
        echo "date.timezone = \"$TIMEZONE\"" > /etc/php/8.1/apache2/conf.d/timezone.ini; \
        echo "date.timezone = \"$TIMEZONE\"" > /etc/php/8.1/cli/conf.d/timezone.ini; \
    fi && \
    sed -i 's,session.cookie_httponly = *\(on\|off\|true\|false\|0\|1\)\?,session.cookie_httponly = on,gi' /etc/php/8.1/apache2/php.ini && \
    if !(grep -q "TLS_REQCERT" /etc/ldap/ldap.conf); then \
        echo "TLS_REQCERT isn't present"; \
        echo -e "TLS_REQCERT\tnever" >> /etc/ldap/ldap.conf; \
    fi && \
    if [ "$(ls ${FOLDER_WEB}${FOLDER_GLPI})" ]; then \
        echo "GLPI is already installed"; \
    else \
        SRC_GLPI=$(curl -s https://api.github.com/repos/glpi-project/glpi/releases/tags/${VERSION_GLPI} | jq .assets[0].browser_download_url | tr -d \"); \
        TAR_GLPI=$(basename ${SRC_GLPI}); \
        wget -P ${FOLDER_WEB} ${SRC_GLPI}; \
        tar -xzf ${FOLDER_WEB}${TAR_GLPI} -C ${FOLDER_WEB}; \
        rm -Rf ${FOLDER_WEB}${TAR_GLPI}; \
        chown -R www-data:www-data ${FOLDER_WEB}${FOLDER_GLPI}; \
    fi && \
    LOCAL_GLPI_VERSION=$(ls ${FOLDER_WEB}/${FOLDER_GLPI}/version) && \
    LOCAL_GLPI_MAJOR_VERSION=$(echo $LOCAL_GLPI_VERSION | cut -d. -f1) && \
    LOCAL_GLPI_VERSION_NUM=${LOCAL_GLPI_VERSION//./} && \
    TARGET_GLPI_VERSION="10.0.14" && \
    TARGET_GLPI_VERSION_NUM=${TARGET_GLPI_VERSION//./} && \
    TARGET_GLPI_MAJOR_VERSION=$(echo $TARGET_GLPI_VERSION | cut -d. -f1) && \
    if [[ $LOCAL_GLPI_VERSION_NUM -lt $TARGET_GLPI_VERSION_NUM || $LOCAL_GLPI_MAJOR_VERSION -lt $TARGET_GLPI_MAJOR_VERSION ]]; then \
        echo -e "<VirtualHost *:80>\n\tDocumentRoot /var/www/html/glpi\n\n\t<Directory /var/www/html/glpi>\n\t\tAllowOverride All\n\t\tOrder Allow,Deny\n\t\tAllow from all\n\t</Directory>\n\n\tErrorLog /var/log/apache2/error-glpi.log\n\tLogLevel warn\n\tCustomLog /var/log/apache2/access-glpi.log combined\n</VirtualHost>" > /etc/apache2/sites-available/000-default.conf; \
    else \
        set +H; \
        echo -e "<VirtualHost *:80>\n\tDocumentRoot /var/www/html/glpi/public\n\n\t<Directory /var/www/html/glpi/public>\n\t\tRequire all granted\n\t\tRewriteEngine On\n\t\tRewriteCond %{REQUEST_FILENAME} !-f\n\t\n\t\tRewriteRule ^(.*)$ index.php [QSA,L]\n\t</Directory>\n\n\tErrorLog /var/log/apache2/error-glpi.log\n\tLogLevel warn\n\tCustomLog /var/log/apache2/access-glpi.log combined\n</VirtualHost>" > /etc/apache2/sites-available/000-default.conf; \
    fi && \
    chown -R www-data:www-data /var/www/html/glpi/ && \
    chmod -R u+rwx /var/www/html/glpi/ && \
    /usr/bin/php /var/www/html/glpi/bin/console glpi:database:install --reconfigure --no-interaction --force --db-host=${MARIADB_DB_HOST} --db-port=${MARIADB_DB_PORT} --db-name=${MARIADB_DB_NAME} --db-user=${MARIADB_DB_USER} --db-password=${MARIADB_DB_PASSWORD} && \
    /usr/bin/php /var/www/html/glpi/bin/console migration:timestamps && \
    /usr/bin/php /var/www/html/glpi/bin/console database:enable_timezones && \
    echo "*/2 * * * * www-data /usr/bin/php /var/www/html/glpi/front/cron.php &>/dev/null" > /etc/cron.d/glpi && \
    service cron start && \
    a2enmod rewrite && \
    service apache2 restart && \
    service apache2 stop && \
    pkill -9 apache && \
    /usr/sbin/apache2ctl -D FOREGROUND