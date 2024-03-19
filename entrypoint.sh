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

# Start Apache
apachectl -D FOREGROUND