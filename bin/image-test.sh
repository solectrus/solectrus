#!/usr/bin/env bash
#
# Runs the Docker image the Dockerfile builds and checks that it works. Nothing
# else starts it: the build pushes it and never runs it.
#
# It also checks the two rules it has (see config/docker_image.rb and
# docker/entrypoint.sh), because they need a container and no spec reaches them.
#
#   bin/image-test.sh            builds it from the Dockerfile
#   bin/image-test.sh IMAGE      uses one that is there already
#
set -euo pipefail

cd "$(dirname "$0")/.."

IMAGE="${1:-}"
if [ -z "${IMAGE}" ]; then
  IMAGE=solectrus-image-test
  echo "Building ${IMAGE} ..."
  docker build -t "${IMAGE}" .
fi

SCRATCH="$(mktemp -d)"
trap 'rm -rf "${SCRATCH}"' EXIT
echo 'nothing' >"${SCRATCH}/file"

failures=0

# Runs the Docker image and looks for a pattern in everything it says.
#
#   check "what it does" MATCH|NO-MATCH <pattern> -- <docker run arguments>
check() {
  local name="$1" mode="$2" pattern="$3" output found
  shift 4 # the three above and the --

  output="$(docker run --rm "$@" 2>&1 || true)"
  found=false
  printf '%s\n' "${output}" | grep -qE "${pattern}" && found=true

  case "${mode}:${found}" in
  MATCH:true | NO-MATCH:false)
    printf '  \033[32mok\033[0m   %s\n' "${name}"
    return
    ;;
  esac

  printf '  \033[31mFAIL\033[0m %s\n' "${name}"
  printf '       %s /%s/, got:\n' "${mode}" "${pattern}"
  printf '%s\n' "${output}" | tail -4 | sed 's/^/       > /'
  failures=$((failures + 1))
}
echo ""
echo "The Docker image runs:"

check "the application boots" MATCH 'Rails [0-9]' -- \
  "${IMAGE}" ./bin/rails --version

# A tool that recreates a container from the configuration of the old one can
# keep the env vars of an older image. The version comes from the file the base
# image writes, so the old value must not arrive.
version="$(docker image inspect "${IMAGE}" \
  --format '{{range .Config.Env}}{{println .}}{{end}}' | sed -n 's/^COMMIT_VERSION=//p')"

check "its own version at the start" MATCH "^Version ${version}, built on" -- \
  -e COMMIT_VERSION=v0.0.0-stale "${IMAGE}" true

# The application reads the same file (see config/initializers/git.rb). Booting
# it needs a database, so this asks the reader directly.
check "its own version in the application" MATCH "^version=${version}\$" -- \
  --entrypoint ruby -e COMMIT_VERSION=v0.0.0-stale "${IMAGE}" \
  -e 'require "/app/lib/build_info"; puts "version=#{BuildInfo.read["COMMIT_VERSION"]}"'

# The mark of the Docker image lies in it, so nothing may put a file there.
check "its own root belongs to root" MATCH 'Permission denied' -- \
  --entrypoint sh "${IMAGE}" -c 'touch /app/.probe'

echo ""
echo "The Docker image refuses:"

check "the user root" MATCH 'must not run as root' -- \
  --user root "${IMAGE}" ./bin/rails --version

# Read while config/application.rb loads, so a command that never builds the
# application does not reach it. Without the entrypoint as well, because the
# entrypoint is not what holds the name.
check "another name than production" MATCH 'the Docker image runs production' -- \
  --entrypoint ruby -e RAILS_ENV=development \
  "${IMAGE}" -e 'require_relative "/app/config/application"'

# The way a service starts it. A binstub loads bin/spring before
# config/boot.rb, and that stops the process under this name for a reason of
# its own, so the check asks only that nothing boots.
check "that name on the way a service starts it" NO-MATCH 'booted' -- \
  -e RAILS_ENV=development "${IMAGE}" ./bin/rails runner 'puts :booted'

echo ""
if [ "${failures}" -gt 0 ]; then
  printf '\033[31m%s check(s) failed\033[0m\n' "${failures}"
  exit 1
fi

printf '\033[32mThe Docker image works\033[0m\n'
