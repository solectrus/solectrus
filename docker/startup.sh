#! /bin/sh

echo "Starting SOLECTRUS..."
echo "Version: $COMMIT_VERSION - $COMMIT_TIME"
echo "----------------"

# Wait for InfluxDB
until nc -z -v -w30 "$INFLUX_HOST" ${INFLUX_PORT:-8086}; do
  echo "Waiting for InfluxDB on $INFLUX_HOST:${INFLUX_PORT:-8086} ..."
  sleep 1
done
echo "InfluxDB is up and running!"

# Wait for PostgreSQL
until nc -z -v -w30 "$DB_HOST" 5432; do
  echo "Waiting for PostgreSQL on $DB_HOST:5432 ..."
  sleep 1
done
echo "PostgreSQL is up and running!"

# Create or migrate database
echo "Preparing database..."
bin/rails db:prepare
echo "Database is ready!"

# Start web server
bundle exec puma -C config/puma.rb
