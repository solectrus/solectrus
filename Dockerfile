FROM ghcr.io/ledermann/rails-base-builder:3.3.0-alpine AS Builder

# Remove some files not needed in resulting image.
# Because they are required for building the image, they can't be added to .dockerignore
RUN rm -r package.json postcss.config.js tailwind.config.ts vite.config.mts tsconfig.json bin/vite

FROM ghcr.io/ledermann/rails-base-final:3.3.0-alpine
LABEL maintainer="georg@ledermann.dev"
LABEL org.opencontainers.image.description="SOLECTRUS Photovoltaic Dashboard"

# Workaround to trigger Builder's ONBUILDs to finish:
COPY --from=Builder /etc/alpine-release /tmp/dummy

ENV HONEYBADGER_LOGGING_LEVEL=WARN
ENV HONEYBADGER_LOGGING_PATH=STDOUT

USER app

# Check whether the internal web server is running properly
HEALTHCHECK --interval=30s --timeout=5s --start-period=10s \
  CMD wget --quiet --tries=1 --spider http://localhost:3000/up || exit 1

# Entrypoint prepares the database.
ENTRYPOINT ["docker/entrypoint.sh"]

# Start the server by default, this can be overwritten at runtime
CMD ["./bin/rails", "server"]
