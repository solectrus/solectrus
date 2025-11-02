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
