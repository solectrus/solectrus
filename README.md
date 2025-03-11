[![Build Status](https://github.com/solectrus/solectrus/workflows/Continuous%20integration/badge.svg)](https://github.com/solectrus/solectrus/actions)
[![Maintainability](https://api.codeclimate.com/v1/badges/10d74fb7665c045afcf4/maintainability)](https://codeclimate.com/repos/5fe98897e985f4018b001e7d/maintainability)
[![Test Coverage](https://api.codeclimate.com/v1/badges/10d74fb7665c045afcf4/test_coverage)](https://codeclimate.com/repos/5fe98897e985f4018b001e7d/test_coverage)
[![wakatime](https://wakatime.com/badge/user/697af4f5-617a-446d-ba58-407e7f3e0243/project/ce8d6e54-7457-42e5-94a3-33a9d4021d45.svg)](https://wakatime.com/badge/user/697af4f5-617a-446d-ba58-407e7f3e0243/project/ce8d6e54-7457-42e5-94a3-33a9d4021d45)

# SOLECTRUS

SOLECTRUS is a smart photovoltaic dashboard that shows your energy production and usage. It also calculates costs and savings, helping you get the most out of your solar system.

Read here about the motivation (in German):
https://ledermann.dev/blog/2021/02/03/photovoltaik-dashboard-als-web-applikation/

![Screenshot](screenshot.webp)

## Live Demo

A live demo with realtime data is available at https://demo.solectrus.de

## Installation

For self-hosting SOLECTRUS, please look at https://configurator.solectrus.de/

## Development

1. Clone the repo locally:

```bash
git clone git@github.com:solectrus/solectrus.git
cd solectrus
```

2. Install PostgreSQL, Redis, and puma-dev (if not already present). On a Mac with HomeBrew, run this to install from the `Brewfile`:

```bash
brew bundle
```

Ensure that PostgreSQL is running:

```bash
brew services start postgresql@17
```

3. Install and set up [puma-dev](https://github.com/puma/puma-dev) to use HTTPS for development. Do this on macOS:

```bash
sudo puma-dev -setup
puma-dev -install
puma-dev link

# Use Vite via puma-dev proxy
# Adopted from https://github.com/puma/puma-dev#webpack-dev-server
echo 3036 > ~/.puma-dev/vite.solectrus
```

4. Setup the application to install gems and NPM packages and create the database:

```bash
bin/setup
```

5. Start the application locally:

```bash
bin/dev
```

This starts the app and opens https://solectrus.test in your default browser (see `Procfile.dev`).

## Test

After preparing development environment (see above):

```bash
bin/influxdb-restart.sh
DISABLE_SPRING=1 bin/rspec
DISABLE_SPRING=1 RAILS_ENV=test bin/rake cypress:run
open coverage/index.html
```

RuboCop:

```
bin/rubocop
```

ESLint:

```
bin/yarn lint
```

TypeScript:

```
bin/yarn tsc
```

There is a shortcut to run **all** test and linting tools:

```bash
bin/test
```

## Performance monitoring

The [Live Demo](https://demo.solectrus.de) is hosted at Hetzner Cloud. For performance monitoring, it uses [RorVsWild](https://www.rorvswild.com), which is free for OpenSource projects. You can see internal metrics like CPU, memory, and disk usage, as well as request times and errors here:
https://www.rorvswild.com/applications/136101/requests

## License

Copyright (c) 2020-2025 Georg Ledermann, released under the AGPL-3.0 License
