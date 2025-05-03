# syntax=docker/dockerfile:1
# check=error=true

ARG SKIP_BOOTSNAP_PRECOMPILE=true

FROM ghcr.io/ledermann/rails-base-builder:3.4.3-alpine AS builder

# Remove some files not needed in resulting image.
# Because they are required for building the image, they can't be added to .dockerignore
RUN rm -r package.json vite.config.mts tsconfig.json bin/vite

FROM ghcr.io/ledermann/rails-base-final:3.4.3-alpine
LABEL maintainer="georg@ledermann.dev"
LABEL org.opencontainers.image.description="SOLECTRUS Photovoltaic Dashboard"

USER app

# Entrypoint prepares the database.
ENTRYPOINT ["docker/entrypoint.sh"]

# Start the server by default, this can be overwritten at runtime
CMD ["./bin/rails", "server"]
