#!/bin/bash

# Execute the database setup script
/usr/local/bin/db_setup.sh



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
#pkill -9 apache

# Start Apache
apachectl -D FOREGROUND