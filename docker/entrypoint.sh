#! /bin/sh -e

echo "Starting SOLECTRUS..."
echo "Version: $COMMIT_VERSION - $COMMIT_TIME - $COMMIT_BRANCH"
echo "----------------"

# If running the rails server then wait for services
# and create or migrate existing database
if [ "${1}" == "./bin/rails" ] && [ "${2}" == "server" ]; then
  # Remove PID in case of restart after container crash
  rm -f /app/tmp/pids/server.pid

  # Check for necessary environment variables
  if [ -z "$REDIS_URL" ] || [ -z "$INFLUX_HOST" ] || [ -z "$DB_HOST" ]; then
    echo "Error: One or more required environment variables (REDIS_URL, INFLUX_HOST, DB_HOST) are not set. Stopping..."
    exit 1
  fi

  # Wait for Redis
  redis_host=$(echo "$REDIS_URL" | awk -F[/:] '{print $4}')
  redis_port=$(echo "$REDIS_URL" | awk -F[/:] '{print $5}')
  until nc -z -v -w30 "$redis_host" "$redis_port"; do
    echo "Waiting for Redis on $redis_host:$redis_port ..."
    sleep 1
  done
  echo "Redis is up and running!"

  # Wait for InfluxDB
  INFLUX_PORT=${INFLUX_PORT:-8086}
  until nc -z -v -w30 "$INFLUX_HOST" ${INFLUX_PORT}; do
    echo "Waiting for InfluxDB on $INFLUX_HOST:${INFLUX_PORT} ..."
    sleep 1
  done
  echo "InfluxDB is up and running!"

  # Wait for PostgreSQL
  DB_PORT=${DB_PORT:-5432}
  until nc -z -v -w30 "$DB_HOST" ${DB_PORT}; do
    echo "Waiting for PostgreSQL on $DB_HOST:$DB_PORT ..."
    sleep 1
  done
  echo "PostgreSQL is up and running!"

  # Create or migrate database
  echo "Preparing database..."
  DB_PREPARE=true ./bin/rails db:prepare
  echo "Database is ready!"
fi

exec "${@}"
