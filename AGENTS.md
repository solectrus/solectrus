# SOLECTRUS

Rails 8.1 full-stack application for photovoltaic monitoring.

## Stack

- Ruby 4.0, PostgreSQL + InfluxDB (time-series data)
- Hotwire (Turbo + Stimulus), TypeScript, Vite, ViewComponent
- Tailwind CSS v4, Slim templates
- RSpec + Playwright

## Documentation

Detailed documentation lives in `docs/`:

- `docs/conventions.md` - Project-specific frontend and testing conventions
- `docs/sensor-overview.md` - Sensor system architecture and core concepts
- `docs/sensor-reference.md` - Sensor DSL and technical details
- `docs/sensor-sql-queries.md` - SQL query patterns for daily+ timeframes

## Code Quality

```bash
bin/rubocop           # Ruby style (use -A for auto-correct)
bin/slim-lint         # Slim templates
bin/yarn tsc          # TypeScript type checking
bin/yarn lint         # ESLint for TypeScript
bin/brakeman          # Security scan (run occasionally, not per-change)
bin/rspec             # Tests
```

### Mandatory Linting

After creating or modifying code, **always** run the relevant linter(s) before considering the task complete. Fix any issues found.

- **Ruby code** (`.rb`): Run `bin/rubocop` on changed files. Use `-A` to auto-correct, review the result.
- **Slim templates** (`.slim`): Run `bin/slim-lint` on changed files.
- **TypeScript code** (`.ts`): Run `bin/yarn tsc` (type checking) and `bin/yarn lint` (ESLint). Both must pass.

## Frontend

- Stimulus controllers use **TypeScript** (`.ts` files), not JavaScript
- See `docs/conventions.md` for ViewComponent, forms, and Tailwind patterns

## Testing

### Running Tests

- Model specs: `bin/rspec spec/models/<model>_spec.rb`
- Request specs: `bin/rspec spec/requests/<controller>_request_spec.rb`
- System specs: `PLAYWRIGHT_HEADLESS=true bin/rspec spec/system/<feature>_spec.rb`

**System specs are slow** (Playwright browser automation). Only run when:

- UI behavior or JavaScript interactions are affected
- Request specs cannot verify the functionality

Always use `PLAYWRIGHT_HEADLESS=true` for system tests — without it, browser windows appear in foreground and block user interaction.

### Test Guidelines

See `docs/conventions.md` for RSpec conventions, Playwright helpers, and testing guidance.
