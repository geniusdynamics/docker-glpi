#!/bin/bash

# Execute the database setup script
/usr/local/bin/db_setup.sh

# Get the IP address of the machine
IP_ADDRESS=$(hostname -I | awk '{print $1}')

# Set ServerName directive in Apache configuration
echo "ServerName $IP_ADDRESS" >> /etc/apache2/apache2.conf


# Set default Apache configuration
#echo -e "<VirtualHost *:80>\n\tDocumentRoot /var/www/html/glpi\n\n\t<Directory /var/www/html/glpi>\n\t\tAllowOverride All\n\t\tOrder Allow,Deny\n\t\tAllow from all\n\t</Directory>\n\n\tErrorLog /var/log/apache2/error-glpi.log\n\tLogLevel warn\n\tCustomLog /var/log/apache2/access-glpi.log combined\n</VirtualHost>" > /etc/apache2/sites-available/000-default.conf
echo -e "<VirtualHost *:80>
    DocumentRoot /var/www/html/glpi

    <Directory /var/www/html/glpi>
        AllowOverride All
        Order Allow,Deny
        Allow from all
    </Directory>
    <Directory /var/www/html/glpi>
        Require all granted

        RewriteEngine On

        # Ensure authorization headers are passed to PHP.
        # Some Apache configurations may filter them and break usage of API, CalDAV, ...
        RewriteCond %{HTTP:Authorization} ^(.+)$
        RewriteRule .* - [E=HTTP_AUTHORIZATION:%{HTTP:Authorization}]

        # Redirect all requests to GLPI router, unless file exists.
        RewriteCond %{REQUEST_FILENAME} !-f
        RewriteRule ^(.*)$ index.php [QSA,L]
    </Directory>
    ErrorLog /var/log/apache2/error-glpi.log
    LogLevel warn
    CustomLog /var/log/apache2/access-glpi.log combined
</VirtualHost>" > /etc/apache2/sites-available/000-default.conf
# Check for conditions to modify the Apache configuration
# For example, check if a specific file or directory exists
#if [ -d /var/www/html/glpi/public ]; then
    # Modify Apache configuration for a public root directory
#   sed -i 's#/var/www/html/glpi#/var/www/html/glpi/public#g' /etc/apache2/sites-available/000-default.conf
#fi

# Enable mod_rewrite
a2enmod rewrite

# Restart Apache
service apache2 restart

# Fix to really stop Apache
pkill -9 apache

# Start Apache
apachectl -D FOREGROUND