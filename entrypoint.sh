#!/bin/bash

# Execute the database setup script
/usr/local/bin/db_setup.sh


# Set default Apache configuration
echo -e "<VirtualHost *:80>\n\tDocumentRoot /var/www/html/glpi\n\n\t<Directory /var/www/html/glpi>\n\t\tAllowOverride All\n\t\tOrder Allow,Deny\n\t\tAllow from all\n\t</Directory>\n\n\tErrorLog /var/log/apache2/error-glpi.log\n\tLogLevel warn\n\tCustomLog /var/log/apache2/access-glpi.log combined\n</VirtualHost>" > /etc/apache2/sites-available/000-default.conf

# Check for conditions to modify the Apache configuration
# For example, check if a specific file or directory exists
#if [ -d /var/www/html/glpi/public ]; then
    # Modify Apache configuration for a public root directory
#   sed -i 's#/var/www/html/glpi#/var/www/html/glpi/public#g' /etc/apache2/sites-available/000-default.conf
#fi


# Append ServerName directive globally in Apache configuration
echo "ServerName $SERVER_NAME" >> /etc/apache2/apache2.conf

# Enable mod_rewrite
a2enmod rewrite

# Restart Apache
service apache2 restart

# Fix to really stop Apache
pkill -9 apache
# Determine the hostname or IP address of the container
CONTAINER_HOSTNAME=$(hostname)
CONTAINER_IP=$(hostname -I | awk '{print $1}')

# Set a default value for ServerName directive
DEFAULT_SERVER_NAME="localhost"

# Set ServerName directive in Apache configuration
if [ -n "$CONTAINER_HOSTNAME" ] && [ -n "$CONTAINER_IP" ]; then
    SERVER_NAME="$CONTAINER_HOSTNAME $CONTAINER_IP"
elif [ -n "$CONTAINER_HOSTNAME" ]; then
    SERVER_NAME="$CONTAINER_HOSTNAME"
elif [ -n "$CONTAINER_IP" ]; then
    SERVER_NAME="$CONTAINER_IP"
else
    SERVER_NAME="$DEFAULT_SERVER_NAME"
fi

# Start Apache
apachectl -D FOREGROUND