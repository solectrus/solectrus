# SOLECTRUS

Rails 8.1 full-stack application for photovoltaic monitoring. PostgreSQL for records, InfluxDB for time-series data.

## Documentation

- `docs/conventions.md` — frontend and testing conventions (ViewComponent, forms, Tailwind, RSpec, Playwright helpers)
- `docs/sensor-overview.md` — sensor architecture and core concepts
- `docs/sensor-reference.md` — sensor DSL and technical details
- `docs/sensor-sql-queries.md` — SQL query patterns for daily+ timeframes
- `docs/MCP.md` — the built-in MCP server and the tools it exposes
- `spec/llm_test/README.md` — the LLM tests that measure how a model uses those tools

## Mandatory linting

After changing code, run the matching linter and fix what it reports:

- Ruby (`.rb`): `bin/rubocop` (`-A` to auto-correct, review the result)
- Slim (`.slim`): `bin/slim-lint`
- TypeScript (`.ts`): `bun run tsc` **and** `bun run lint` — both must pass
- Shell (`.sh`): `shellcheck`
- Markdown, JSON, YAML, CSS: `bun run format` (Prettier)

`bin/brakeman` occasionally for security scans, not per change.

## Frontend

Stimulus controllers are TypeScript (`.ts`), never JavaScript.

## Development

`bin/setup` once, then `bin/dev` to start Rails, Vite and Caddy together.

## Testing

`bin/rspec [path]`. InfluxDB must be running — start it with `bin/influxdb-restart.sh`, never by hand. The script recreates the `influxdb_v2` container with the org, bucket and token the test environment expects. The local InfluxDB exists for the tests alone, so dropping its data costs nothing — run the script whenever a spec cannot reach InfluxDB.

System specs drive Playwright and are slow — run them only when UI behavior or JavaScript is affected and a request spec cannot cover it. Always with `PLAYWRIGHT_HEADLESS=true`, otherwise browser windows open in the foreground and block the user. They run against compiled assets, so after any frontend change run `bunx vite build --mode test` first.

`bin/llm-test` runs the LLM tests of the MCP server against the `claude` CLI. They
cost subscription usage and take minutes, so run them when a tool description
or the server instructions change — never as part of a normal test run. See
`spec/llm_test/README.md`.

`bin/ci` runs the full gate: every linter above, the security audits, the asset build and both spec runs. It is what CI does, so use it before a release rather than after each change.
