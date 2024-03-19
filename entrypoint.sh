#!/bin/bash

# Enable mod_rewrite
a2enmod rewrite

# Restart Apache
service apache2 restart

# Fix to really stop Apache
#pkill -9 apache

# Execute the database setup script
/usr/local/bin/db_setup.sh

# Start Apache
apachectl -D FOREGROUND