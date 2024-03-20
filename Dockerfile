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
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    ca-certificates \
    apt-transport-https \
    lsb-release \
    wget \
    curl \
    jq \
    software-properties-common \
    cron \
    mariadb-client \
    apache2 \
    && rm -rf /var/lib/apt/lists/* && \
    a2enmod rewrite

# removed sury.org PHP repository and key, install PHP and its extensions
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    php \
    php-common \
    php-mysql \
    php-ldap \
    php-xmlrpc \
    php-imap \
    php-curl \
    php-gd \
    php-mbstring \
    php-xml \
    php-cas \
    php-intl \
    php-zip \
    php-bz2 \
    php-redis \
    && rm -rf /var/lib/apt/lists/* 

# Download GLPI
ARG GLPI_VERSION=10.0.14 # Default version
RUN wget -qO /tmp/glpi-${GLPI_VERSION}.tgz https://github.com/glpi-project/glpi/releases/download/${GLPI_VERSION}/glpi-${GLPI_VERSION}.tgz && \
    tar -xzf /tmp/glpi-${GLPI_VERSION}.tgz -C /var/www/html/ && \
    rm /tmp/glpi-${GLPI_VERSION}.tgz

# GLPI Version Handling - Use sed to modify Apache configuration
RUN sed -i 's#/var/www/html/glpi/public#/var/www/html/glpi#g' /etc/apache2/sites-available/000-default.conf

# PHP configuration modifications
RUN cat <<EOF > /etc/php/apache2/conf.d/99-glpi.ini \
    memory_limit = 64M ;
    file_uploads = on ;
    max_execution_time = 600 ;
    register_globals = off ;
    magic_quotes_sybase = off ;
    session.auto_start = off ;
    session.use_trans_sid = 0 ;
EOF \
    && echo "session.cookie_httponly = on" >> /etc/php/apache2/php.ini \
    && echo "apc.enable_cli = 1 ;" > /etc/php/mods-available/apcu.ini
    
# Add cron job
RUN echo "*/2 * * * * www-data /usr/bin/php /var/www/html/glpi/front/cron.php &>/dev/null" > /etc/cron.d/glpi

# Copy the entrypoint and db_setup scripts
COPY entrypoint.sh /usr/local/bin/
COPY db_setup.sh /usr/local/bin/

# Make scripts executable
RUN chmod +x /usr/local/bin/entrypoint.sh \
    && chmod +x /usr/local/bin/db_setup.sh

# Set proper permissions and configurations for GLPI
RUN chown -R www-data:www-data /var/www/html/glpi/ && \
    find /var/www/html/glpi/ -type d -exec chmod 755 {} \; && \
    find /var/www/html/glpi/ -type f -exec chmod 644 {} \;

# Expose ports, start Apache
EXPOSE 80 443

# Start cron service
CMD ["cron", "-f"]

# Set the entrypoint
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
