# SOLECTRUS

Rails 8.1 full-stack application for photovoltaic monitoring. InfluxDB holds the raw time series, PostgreSQL the daily summaries derived from it.

## Scope

Change what the request names, at the scope it implies. If you see a related
problem outside it, name it in one sentence and leave that code alone.

## Documentation

- `docs/conventions.md` — frontend and testing conventions (ViewComponent, forms, Tailwind, RSpec, Playwright helpers)
- `docs/testing.md` — every test runner: the specs, the full gate, the Docker image, the MCP tools
- `docs/sensor-overview.md` — sensor architecture and core concepts
- `docs/sensor-reference.md` — sensor DSL and technical details
- `docs/sensor-sql-queries.md` — SQL query patterns for daily+ timeframes
- `docs/MCP.md` — the built-in MCP server and the tools it exposes

Keep a document here to its substance: no filler sections, no repeated
summaries.

## Mandatory linting

After changing code, run the matching linter and fix what it reports:

- Ruby (`.rb`): `bin/rubocop` (`-A` to auto-correct, review the result)
- Slim (`.slim`): `bin/slim-lint`
- TypeScript (`.ts`): `bun run tsc` **and** `bun run lint` — both must pass
- Shell (`.sh`): `shellcheck`
- Markdown, JSON, YAML, CSS: `bun run format` (Prettier)

`bin/brakeman` before a release, or after a change to authentication, parameters
or SQL.

## Changelog

If a user can see or feel a change, add a line to `.changelog/unreleased.md` in
the same commit. The file carries the rules for the wording.

## Testing

`bin/rspec [path]`. Start InfluxDB with `bin/influxdb-restart.sh`, never by hand.

System specs drive Playwright: only when a request spec cannot cover the
behavior, always `PLAYWRIGHT_HEADLESS=true`, and after a frontend change
`bunx vite build --mode test` first.

Run the specs that cover your change. `bin/ci` is the full gate, before a
release rather than after each change. `docs/testing.md` covers it and the other
runners (Docker image, MCP tools, iOS simulator).

## Development

`bin/setup` once, then `bin/dev` to start Rails, Vite and Caddy together.
Stimulus controllers are TypeScript (`.ts`), never JavaScript.
