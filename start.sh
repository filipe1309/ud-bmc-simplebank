#!/bin/sh

set -e # Exit on error

# echo "run db migrations"
# sed -i 's/localhost/postgres/g' /app/app.env
# source /app/app.env
# /app/migrate -path /app/migration -database "$DB_SOURCE" -verbose up

echo "start app"
exec "$@" # Pass command line arguments to the app and run it
