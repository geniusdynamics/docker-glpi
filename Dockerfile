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
    php-intl \
    php-zip \
    php-bz2 \
    php-redis \
    && a2enmod rewrite \
    && rm -rf /var/lib/apt/lists/*

# Download GLPI
ARG GLPI_VERSION=10.0.14 # Default version
RUN wget -qO /tmp/glpi-${GLPI_VERSION}.tgz https://github.com/glpi-project/glpi/releases/download/${GLPI_VERSION}/glpi-${GLPI_VERSION}.tgz && \
    tar -xzf /tmp/glpi-${GLPI_VERSION}.tgz -C /var/www/html/ && \
    rm /tmp/glpi-${GLPI_VERSION}.tgz

# GLPI Version Handling - Use sed to modify Apache configuration
RUN sed -i 's#/var/www/html/glpi/public#/var/www/html/glpi#g' /etc/apache2/sites-available/000-default.conf

# PHP configuration modifications
RUN echo "memory_limit = 64M ;" > /etc/php/8.2/apache2/conf.d/99-glpi.ini && \
    echo "file_uploads = on ;" >> /etc/php/8.2/apache2/conf.d/99-glpi.ini && \
    echo "max_execution_time = 600 ;" >> /etc/php/8.2/apache2/conf.d/99-glpi.ini && \
    echo "register_globals = off ;" >> /etc/php/8.2/apache2/conf.d/99-glpi.ini && \
    echo "magic_quotes_sybase = off ;" >> /etc/php/8.2/apache2/conf.d/99-glpi.ini && \
    echo "session.auto_start = off ;" >> /etc/php/8.2/apache2/conf.d/99-glpi.ini && \
    echo "session.use_trans_sid = 0 ;" >> /etc/php/8.2/apache2/conf.d/99-glpi.ini && \
    echo "session.cookie_httponly = on" >> /etc/php/8.2/apache2/php.ini && \
    echo "apc.enable_cli = 1 ;" > /etc/php/8.2/mods-available/apcu.ini

# Add cron job
RUN echo "*/2 * * * * www-data /usr/bin/php /var/www/html/glpi/front/cron.php &>/dev/null" > /etc/cron.d/glpi

# Copy the entrypoint and db_setup scripts
COPY entrypoint.sh /usr/local/bin/
COPY db_setup.sh /usr/local/bin/

# Make scripts executable
RUN chmod +x /usr/local/bin/entrypoint.sh \
    && chmod +x /usr/local/bin/db_setup.sh
