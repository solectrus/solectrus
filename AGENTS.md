# SOLECTRUS

Rails 8.1 full-stack application for photovoltaic monitoring. PostgreSQL for records, InfluxDB for time-series data.

## Documentation

- `docs/conventions.md` — frontend and testing conventions (ViewComponent, forms, Tailwind, RSpec, Playwright helpers)
- `docs/testing.md` — every test runner: the specs, the full gate, the Docker image, the MCP tools
- `docs/sensor-overview.md` — sensor architecture and core concepts
- `docs/sensor-reference.md` — sensor DSL and technical details
- `docs/sensor-sql-queries.md` — SQL query patterns for daily+ timeframes
- `docs/MCP.md` — the built-in MCP server and the tools it exposes

## Mandatory linting

After changing code, run the matching linter and fix what it reports:

- Ruby (`.rb`): `bin/rubocop` (`-A` to auto-correct, review the result)
- Slim (`.slim`): `bin/slim-lint`
- TypeScript (`.ts`): `bun run tsc` **and** `bun run lint` — both must pass
- Shell (`.sh`): `shellcheck`
- Markdown, JSON, YAML, CSS: `bun run format` (Prettier)

`bin/brakeman` occasionally for security scans, not per change.

## Changelog

If a user can see or feel a change, add a line to `.changelog/unreleased.md` in
the same commit. The file carries the rules for the wording. The release skill
turns it into the GitHub release notes and empties it.

## Frontend

Stimulus controllers are TypeScript (`.ts`), never JavaScript.

## Development

`bin/setup` once, then `bin/dev` to start Rails, Vite and Caddy together.

## Testing

`bin/rspec [path]`. Start InfluxDB with `bin/influxdb-restart.sh`, never by hand.

System specs drive Playwright: only when a request spec cannot cover the
behavior, always `PLAYWRIGHT_HEADLESS=true`, and after a frontend change
`bunx vite build --mode test` first.

`bin/ci` is the full gate, before a release. `docs/testing.md` covers it and the
other runners (Docker image, MCP tools, iOS simulator).
