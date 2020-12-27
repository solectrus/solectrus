#! /bin/sh

echo "Starting Solectrus..."
echo "Git commit: $COMMIT_SHA - $COMMIT_TIME"
echo "----------------"

# Wait for PostgreSQL
until nc -z -v -w30 $DB_HOST 5432
do
  echo "Waiting for PostgreSQL..."
  sleep 1
done
echo "PostgreSQL is up and running!"

# Create or migrate database
echo "Preparing database..."
bundle exec rails db:prepare
echo "Database is ready!"

# Start web server
bundle exec puma -C config/puma.rb
