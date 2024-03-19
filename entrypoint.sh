#!/bin/bash

# Execute the database setup script
/tmp/db_setup.sh

# Start Apache or any other services
apachectl -D FOREGROUND
