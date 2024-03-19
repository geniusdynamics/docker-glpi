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

# Add Ondrej's PHP PPA (or Sury's, but not both)
RUN apt-key adv --keyserver keyserver.ubuntu.com --recv-keys 4F4EA0AAE5267A6C && \
    echo "deb https://ppa.launchpad.net/ondrej/php/ubuntu jammy main" > /etc/apt/sources.list.d/php.list

# Update and install PHP
RUN apt-get update && apt-get install -y \
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
RUN echo -e "<VirtualHost *:80>\n\tDocumentRoot /var/www/html/glpi\n\n\t<Directory /var/www/html/glpi>\n\t\tAllowOverride All\n\t\tOrder Allow,Deny\n\t\tAllow from all\n\t</Directory>\n\n\tErrorLog /var/log/apache2/error-glpi.log\n\tLogLevel warn\n\tCustomLog /var/log/apache2/access-glpi.log combined\n</VirtualHost>" > /etc/apache2/sites-available/000-default.conf

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
RUN mkdir -p /var/www/html/glpi && \
    chown -R www-data:www-data /var/www/html/glpi && \
    chmod -R u+rwx /var/www/html/glpi

# GLPI installation (Assuming it's already downloaded)
COPY glpi /var/www/html/ 

# Database setup script
COPY db_setup.sh /tmp/
RUN chmod +x /tmp/db_setup.sh

# Execute the database setup script
RUN /tmp/db_setup.sh

# Expose ports, start Apache
EXPOSE 80 443
CMD ["apachectl", "-D", "FOREGROUND"]
