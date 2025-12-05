# ClaudeOnRails Context

This project uses ClaudeOnRails with a swarm of specialized agents for Rails development.

## Project Information

- **Type**: Full-stack Rails application
- **Database**: PostgreSQL + InfluxDB (time-series data)
- **Frontend**: Hotwire (Turbo + Stimulus), TypeScript, Tailwind CSS
- **Templates**: Slim
- **Testing**: RSpec with Playwright

## Swarm Configuration

The claude-swarm.yml file defines specialized agents for different aspects of Rails development:

- Each agent has specific expertise and works in designated directories
- Agents collaborate to implement features across all layers
- The architect agent coordinates the team

## Development Guidelines

When working on this project:

- Follow Rails conventions and best practices
- Write tests for all new functionality
- Use strong parameters in controllers
- Keep models focused with single responsibilities
- Extract complex business logic to service objects
- Ensure proper database indexing for foreign keys and queries

## Testing Workflow

Before committing changes, always run all tests related to the modified code:

1. **Find related tests**: Use `grep` or `glob` to find all spec files that test the changed code
2. **Run model specs**: `bin/rspec spec/models/<model>_spec.rb` for model changes
3. **Run request specs**: `bin/rspec spec/requests/<controller>_request_spec.rb` for controller changes
4. **Run system specs** (sparingly): `bin/rspec spec/system/<feature>_spec.rb HEADLESS=true`

### Important notes on system tests

- System tests are slow (use Playwright browser automation) - only run when UI behavior is affected
- Always use `HEADLESS=true` to avoid disrupting foreground work
- Prefer request specs over system specs when testing controller logic
- Only run the specific system spec file needed, not the entire suite
