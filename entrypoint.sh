#!/bin/bash

# Execute the database setup script
/usr/local/bin/db_setup.sh

# Start Apache or any other services
#apachectl -D FOREGROUND
exec apache2-foreground
