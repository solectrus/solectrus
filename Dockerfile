# syntax=docker/dockerfile:1
# check=error=true

ARG SKIP_BOOTSNAP_PRECOMPILE=true

FROM ghcr.io/ledermann/rails-base-builder:4.0.7-alpine AS builder

# Remove some files not needed in resulting image.
# Because they are required for building the image, they can't be added to .dockerignore
RUN rm -r package.json vite.config.mts tsconfig.json public/vite/assets/test*

FROM ghcr.io/ledermann/rails-base-final:4.0.7-alpine

# Tells the Docker image from a working copy (see config/docker_image.rb). The
# directory belongs to root and the application does not, so the application
# cannot take the file away. A working copy carries every file of the
# repository and this one is in none of them.
RUN touch .image

USER app

# Enable YJIT
ENV RUBY_YJIT_ENABLE=1

# Entrypoint prepares the database.
ENTRYPOINT ["docker/entrypoint.sh"]

# Start the server by default, this can be overwritten at runtime
CMD ["./bin/rails", "server"]
