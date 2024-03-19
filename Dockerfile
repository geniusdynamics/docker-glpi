FROM debian:12.5

LABEL org.opencontainers.image.authors="github@genius.ke"
ENV DEBIAN_FRONTEND noninteractive

# Define build arguments
ARG MARIADB_DB_HOST
ARG MARIADB_DB_USER
ARG MARIADB_DB_PASSWORD
ARG MARIADB_DB_NAME
ARG MARIADB_DB_PORT

# Set environment variables using build arguments
ENV MARIADB_DB_HOST=$MARIADB_DB_HOST
ENV MARIADB_DB_USER=$MARIADB_DB_USER
ENV MARIADB_DB_PASSWORD=$MARIADB_DB_PASSWORD
ENV MARIADB_DB_NAME=$MARIADB_DB_NAME
ENV MARIADB_DB_PORT=$MARIADB_DB_PORT

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
    echo "session.cookie_httponly = on" >> /etc/php/8.1/apache2/php.ini && \
    echo "apc.enable_cli = 1 ;" > /etc/php/8.1/mods-available/apcu.ini

# Set permissions and configurations for GLPI
RUN chown -R www-data:www-data /var/www/html/glpi && \
    chmod -R u+rwx /var/www/html/glpi

# Copy the entrypoint and db_setup scripts
COPY entrypoint.sh /usr/local/bin/
COPY db_setup.sh /usr/local/bin/

# Set proper permissions and configurations for GLPI
RUN if [ -f /docker-entrypoint-initdb.d/zz_glpi_restore.sh ]; then \
        echo -e "<VirtualHost *:80>\n\tDocumentRoot /var/www/html/glpi\n\n\t<Directory /var/www/html/glpi>\n\t\tAllowOverride All\n\t\tOrder Allow,Deny\n\t\tAllow from all\n\t</Directory>\n\n\tErrorLog /var/log/apache2/error-glpi.log\n\tLogLevel warn\n\tCustomLog /var/log/apache2/access-glpi.log combined\n</VirtualHost>" > /etc/apache2/sites-available/000-default.conf; \
    else \
        echo -e "<VirtualHost *:80>\n\tDocumentRoot /var/www/html/glpi/public\n\n\t<Directory /var/www/html/glpi/public>\n\t\tRequire all granted\n\t\tRewriteEngine On\n\t\tRewriteCond %{REQUEST_FILENAME} !-f\n\t\n\t\tRewriteRule ^(.*)$ index.php [QSA,L]\n\t</Directory>\n\n\tErrorLog /var/log/apache2/error-glpi.log\n\tLogLevel warn\n\tCustomLog /var/log/apache2/access-glpi.log combined\n</VirtualHost>" > /etc/apache2/sites-available/000-default.conf; \
    fi && \
    chown -R www-data:www-data /var/www/html/glpi/ && \
    chmod -R u+rwx /var/www/html/glpi/

# Add cron job
RUN echo "*/2 * * * * www-data /usr/bin/php /var/www/html/glpi/front/cron.php &>/dev/null" > /etc/cron.d/glpi


# Make scripts executable
RUN chmod +x /usr/local/bin/entrypoint.sh \
    && chmod +x /usr/local/bin/db_setup.sh

# Start cron service
CMD ["cron", "-f"]

# Enable mod_rewrite
RUN a2enmod rewrite

# Restart Apache
#RUN service apache2 restart

# Stop Apache gracefully
RUN service apache2 stop
# Expose ports, start Apache
EXPOSE 80 443

# Set the entrypoint
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
