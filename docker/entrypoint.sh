#!/bin/sh -e
echo "SOLECTRUS Photovoltaic Dashboard"

# Format version string based on branch context
if [ -n "${COMMIT_BRANCH}" ] && [ "${COMMIT_BRANCH}" != "main" ] && [ "${COMMIT_BRANCH}" != "develop" ]; then
  # For feature branches: extract second and third parts from COMMIT_VERSION
  # Example: v0.20.3-170-g8349036 -> 1-0-beta-170-g8349036
  PART2=$(echo "${COMMIT_VERSION}" | cut -d'-' -f2)
  PART3=$(echo "${COMMIT_VERSION}" | cut -d'-' -f3)

  if [ -n "${PART2}" ] && [ -n "${PART3}" ]; then
    VERSION_STRING="${COMMIT_BRANCH}-${PART2}-${PART3}"
  else
    VERSION_STRING="${COMMIT_VERSION}"
  fi
else
  # For main/develop branches or tagged releases: use original version
  VERSION_STRING="${COMMIT_VERSION}"
fi

echo "Version ${VERSION_STRING}, built on ${COMMIT_TIME}"
echo "Using $(ruby -v)"
echo "Based on Alpine Linux $(cat /etc/alpine-release)"

echo ""
echo "Copyright (C) 2020-2025 Georg Ledermann"
echo "License: GNU AGPLv3 - https://www.gnu.org/licenses/agpl-3.0.html"

# If running the rails server then wait for services
# and create or migrate existing database
if [ "${1}" == "./bin/rails" ] && [ "${2}" == "server" ]; then
  # Check for necessary environment variables
  if [ -z "${REDIS_URL}" ] || [ -z "${INFLUX_HOST}" ] || [ -z "${DB_HOST}" ]; then
    echo "Error: One or more required environment variables (REDIS_URL, INFLUX_HOST, DB_HOST) are not set. Stopping..." >&2
    exit 1
  fi

  echo ""
  echo "## Waiting for services..."

  # Wait for Redis
  redis_host=$(echo "${REDIS_URL}" | awk -F[/:] '{print $4}')
  redis_port=$(echo "${REDIS_URL}" | awk -F[/:] '{print $5}')
  until nc -z -v -w30 "${redis_host}" "${redis_port}"; do
    echo "Waiting for Redis on ${redis_host}:${redis_port} ..."
    sleep 1
  done
  echo "Redis is up and running!"

  # Wait for InfluxDB
  INFLUX_PORT=${INFLUX_PORT:-8086}
  until nc -z -v -w30 "${INFLUX_HOST}" "${INFLUX_PORT}"; do
    echo "Waiting for InfluxDB on ${INFLUX_HOST}:${INFLUX_PORT} ..."
    sleep 1
  done
  echo "InfluxDB is up and running!"

  # Wait for PostgreSQL
  DB_PORT=${DB_PORT:-5432}
  until nc -z -v -w30 "${DB_HOST}" "${DB_PORT}"; do
    echo "Waiting for PostgreSQL on ${DB_HOST}:${DB_PORT} ..."
    sleep 1
  done
  echo "PostgreSQL is up and running!"

  # Create or migrate database
  echo ""
  echo "## Preparing database..."
  ./bin/rails db:prepare
  echo "Database is ready!"

  echo ""
  echo "## Starting Rails application..."
fi

exec "${@}"
