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
bin/slim_lint         # Slim templates
bin/brakeman          # Security scan
bin/rspec             # Tests
```

## Frontend

- Stimulus controllers use **TypeScript** (`.ts` files), not JavaScript
- UI components use **ViewComponent** (`app/components/`)
- Forms use `TailwindFormBuilder`
- See `docs/conventions.md` for examples and patterns

## Testing

### Running Tests

- Model specs: `bin/rspec spec/models/<model>_spec.rb`
- Request specs: `bin/rspec spec/requests/<controller>_request_spec.rb`
- System specs: `bin/rspec spec/system/<feature>_spec.rb HEADLESS=true`

**System specs are slow** (Playwright browser automation). Only run when:

- UI behavior or JavaScript interactions are affected
- Request specs cannot verify the functionality

Always use `HEADLESS=true` — without it, browser windows appear in foreground and block user interaction.

### Test Guidelines

- Write tests **before** implementation (TDD)
- Prefer real objects over mocks
- Use mocks only for external APIs or expensive operations
- See `docs/conventions.md` for RSpec conventions, Playwright helpers, and testing guidance
