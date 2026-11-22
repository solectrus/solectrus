#!/usr/bin/env bash

# Start Redis via Docker for the specs tagged :redis (spec/support/redis.rb).
# The version that HELIOS installs, the same image as in the GitHub workflow.

set -e

DEFAULT_REDIS_V8_VERSION="8-alpine"
REDIS_V8_VERSION="${REDIS_V8_VERSION:-$DEFAULT_REDIS_V8_VERSION}"
REDIS_V8_IMAGE=redis:${REDIS_V8_VERSION}

docker rm --force redis_v8 >/dev/null 2>&1 || true

echo
echo "Restarting Redis 8.x [${REDIS_V8_IMAGE}] ... "
echo

docker pull "${REDIS_V8_IMAGE}" || true
docker run \
       --detach \
       --name redis_v8 \
       --publish 6379:6379 \
       "${REDIS_V8_IMAGE}"
