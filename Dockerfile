FROM ghcr.io/ledermann/rails-base-builder:3.3.5-alpine AS builder

# Remove some files not needed in resulting image.
# Because they are required for building the image, they can't be added to .dockerignore
RUN rm -r package.json postcss.config.js tailwind.config.ts vite.config.mts tsconfig.json bin/vite

FROM ghcr.io/ledermann/rails-base-final:3.3.5-alpine
LABEL maintainer="georg@ledermann.dev"
LABEL org.opencontainers.image.description="SOLECTRUS Photovoltaic Dashboard"

# Workaround to trigger builder's ONBUILDs to finish:
COPY --from=builder /etc/alpine-release /tmp/dummy

USER app

# Entrypoint prepares the database.
ENTRYPOINT ["docker/entrypoint.sh"]

# Start the server by default, this can be overwritten at runtime
CMD ["./bin/rails", "server"]
