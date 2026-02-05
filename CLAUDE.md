# SOLECTRUS

Rails 8.1 full-stack application for photovoltaic monitoring.

## Stack

- Ruby 4.0, PostgreSQL + InfluxDB (time-series data)
- Hotwire (Turbo + Stimulus), TypeScript, Vite, ViewComponent
- Tailwind CSS v4, Slim templates
- RSpec + Playwright

## Code Quality

```bash
bin/rubocop           # Ruby style (use -A for auto-correct)
bin/slim_lint         # Slim templates
bin/brakeman          # Security scan
bin/rspec             # Tests
```

## Frontend

### Stimulus Controllers

All controllers use **TypeScript** (`.ts` files), not JavaScript:

```typescript
import { Controller } from '@hotwired/stimulus';

export default class extends Controller {
  static targets = ['menu'] as const;
  declare readonly menuTarget: HTMLElement;
}
```

### ViewComponent

UI components live in `app/components/` with Ruby class + Slim template:

```ruby
# app/components/button/component.rb
class Button::Component < ViewComponent::Base
  def initialize(variant: :primary)
    @variant = variant
  end
end
```

### Tailwind CSS

For classes with `@` (container queries), use attribute syntax:

```slim
/ Good
div class='text-base @c1:text-xl'
div class=['text-base', dynamic_class]

/ Avoid
.text-base.@c1:text-xl
```

### Forms

Use `TailwindFormBuilder` for styled forms:

```slim
= form_with model: @record, builder: TailwindFormBuilder do |form|
  = form.group :name
  = form.submit
```

## Testing

### Running Tests

- Model specs: `bin/rspec spec/models/<model>_spec.rb`
- Request specs: `bin/rspec spec/requests/<controller>_request_spec.rb`
- System specs: `bin/rspec spec/system/<feature>_spec.rb HEADLESS=true`

**System specs are slow** (Playwright browser automation). Only run when:

- UI behavior or JavaScript interactions are affected
- Request specs cannot verify the functionality

Always use `HEADLESS=true` — without it, browser windows appear in foreground and block user interaction.

### RSpec Conventions

Always use **named subjects**:

```ruby
# Good
subject(:user) { build(:user) }
subject(:result) { service.call }

# Bad
subject { build(:user) }
```

Structure with describe/context/subject:

```ruby
describe User do
  subject(:user) { build(:user, email:) }

  describe '#valid?' do
    subject(:valid) { user.valid? }

    context 'when email is blank' do
      let(:email) { '' }
      it { is_expected.to be false }
    end
  end
end
```

### Test Guidelines

- Write tests **before** implementation (TDD)
- Don't test private methods or trivial code
- Prefer real objects over mocks
- Use mocks only for external APIs or expensive operations

### Playwright Helpers

- `travel_js(milliseconds)` - JavaScript time manipulation
- `influx_seed` / `influx_purge` - InfluxDB test data setup
