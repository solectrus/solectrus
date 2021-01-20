FROM ledermann/rails-base-builder:2.7.2-alpine AS Builder

# Remove some files not needed in resulting image.
# Because they are required for building the image, they can't be added to .dockerignore
RUN rm -r package.json yarn.lock postcss.config.js babel.config.js tailwind.config.js

FROM ledermann/rails-base-final:2.7.2-alpine
LABEL maintainer="georg@ledermann.dev"

USER app

# Start up
CMD ["docker/startup.sh"]
