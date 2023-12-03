FROM ghcr.io/ledermann/rails-base-builder:3.2.2-alpine AS Builder

# Remove some files not needed in resulting image.
# Because they are required for building the image, they can't be added to .dockerignore
RUN rm -r package.json postcss.config.js tailwind.config.ts vite.config.mts tsconfig.json bin/vite

FROM ghcr.io/ledermann/rails-base-final:3.2.2-alpine
LABEL maintainer="georg@ledermann.dev"
LABEL org.opencontainers.image.description="SOLECTRUS Photovoltaic Dashboard"

# Workaround to trigger Builder's ONBUILDs to finish:
COPY --from=Builder /etc/alpine-release /tmp/dummy

ENV HONEYBADGER_LOGGING_LEVEL=WARN
ENV HONEYBADGER_LOGGING_PATH=STDOUT

USER app

# Script to be executed every time the container starts
ENTRYPOINT ["docker/startup.sh"]
