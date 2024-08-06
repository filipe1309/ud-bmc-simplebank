#!/bin/sh

set -e # Exit on error

echo "run db migrations"
cat /app/app.env
source /app/app.env
echo "DB_SOURCE: $DB_SOURCE"
/app/migrate -path /app/migration -database "$DB_SOURCE" -verbose up

echo "start app"
exec "$@" # Pass command line arguments to the app and run it
