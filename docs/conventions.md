# Code Conventions

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

### Tailwind CSS in Slim

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

### Playwright Helpers

- `travel_js(milliseconds)` - JavaScript time manipulation
- `influx_seed` / `influx_purge` - InfluxDB test data setup

### Test Guidelines

- Write tests **before** implementation (TDD)
- Don't test private methods or trivial code
- Prefer real objects over mocks
- Use mocks only for external APIs or expensive operations
