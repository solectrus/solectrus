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

UI components live in `app/components/` with Ruby class + Slim template. The
directory is the name, the files inside are always `component.rb` and
`component.html.slim`:

```ruby
# app/components/ui/button/component.rb
class Ui::Button::Component < ViewComponent::Base
  def initialize(variant: :primary)
    @variant = variant
  end
end
```

Directories nest where a family of components belongs together, and the class
name follows:

```
app/components/nav/top/component.rb        # Nav::Top::Component
app/components/notification/badge/component.rb  # Notification::Badge::Component
```

A component that another app could use as it is, like a button or a dialog,
lives in `app/components/ui/` and in the namespace `Ui::`. A component that
knows SOLECTRUS stays outside it. `docs/ui.md` lists the `Ui::` components.

`app/components/concerns/` is the exception. It holds shared modules
(`BreakdownTable`, `ChartDropdownLogic`), not components.

### Views, components and helpers

A view or a partial belongs to a controller action. The view renders the page
of the action. A partial is a part of such a page:

- The `_form` partial of the `new` and `edit` views, and its sections.
  `FormPageResponse` renders it again when a record does not save.
- The `_sub_nav` partial, which fills the header of the pages of a controller
  through `content_for`.
- A partial that several formats of one action share, like `errors/_message`.

The layouts keep their own partials in `app/views/layouts/`.

Everything else is a ViewComponent: a list, a row, a cell, a chip. A Turbo
Stream renders the component directly, not a partial around it:

```ruby
turbo_stream.update('list', PriceList::Component.new(prices:, name:))
```

When two components show the same text, a module in `app/components/concerns/`
holds it, like `ChargingSessionTexts`. Such a module reads the record from a
method of the component, like `charging_session`.

A helper in `app/helpers/` is for code that many views and components use: the
`icon`, the form builder, the paths of the sensors and the theme. A helper also
gives a form partial its choices, like `car_options`. Code that only components
call must go into a component or a concern.

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

`TailwindFormBuilder` is the `default_form_builder` of `ApplicationController`,
so every form is styled without naming a builder:

```slim
= form_with model: @record, url: some_path, method: :patch do |f|
  = f.group do
    = f.text_field :name, placeholder: '...'

  = f.group title: t('...') do
    = f.check_box :enabled, label: t('...'), hint: t('...')

  = f.actions do
    = f.submit t('...')
```

`group` takes an optional `title:` and a block of fields, not a field name. The
builder wraps label, hint and error message around each field, so a template
writes none of them. It offers `text_field`, `number_field`, `password_field`,
`date_field`, `select`, `check_box`, `group`, `actions` and `submit`.

### Questions before an action

`data-turbo-confirm` asks in the dialog of `Ui::ConfirmDialog::Component`, not in
the confirm of the browser. Start the text with a short question that names the
action. Put the result after it. The dialog shows the question in bold and the
rest below it. The text does not address the user. The cancel button says
"Abbrechen". Give
the confirm button "Yes" and the verb of the action with
`button:`, from the `confirm` namespace, like "Ja, löschen". If the
action removes something, add `destructive: true` to show the button in red.
`Ui::ConfirmDialog::Component.data` builds the attributes, and `delete_data` holds
the question before a delete:

```slim
= button_to path, method: :patch,
            form: { data: Ui::ConfirmDialog::Component.data(t('...'), button: t('confirm.dismiss'), destructive: true) }
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

From `spec/support/system.rb`:

- `travel_js(seconds)` - JavaScript time manipulation (the helper converts to milliseconds itself)
- `influx_seed(base_time:)` - writes PV, heat pump, car SOC and forecast data plus the matching summaries, in one batch
- `influx_purge` - drops that data and the summaries again
- `create_summary(date:, updated_at:, values:)` - one summary row without touching InfluxDB

From `spec/support/system_helpers.rb`:

- `accept_confirm_dialog { ... }` and `dismiss_confirm_dialog { ... }` - answer the question of `Ui::ConfirmDialog::Component` that the block raises, and return it

### Test Guidelines

- Write tests **before** implementation (TDD)
- Don't test private methods or trivial code
- Prefer real objects over mocks
- Use mocks only for external APIs or expensive operations

### Parallel Runs

`bin/ci` runs the specs on several processes at the same time. Each process gets its own Postgres database and its own InfluxDB bucket. Both carry the number that `parallel_tests` puts into `TEST_ENV_NUMBER`. A plain `bin/rspec` run gets no such number and keeps the `solectrus_test` database and the `my-bucket` bucket.

A spec must not depend on a name or a resource that all processes share:

- Read the bucket name from `Rails.configuration.x.influx.bucket`. Do not write `my-bucket` into a spec.
- Do not let one spec file depend on data that another spec file wrote. `parallel_tests` splits the files over the processes, and the two files can land in different processes.
- If a spec needs a port or a file path of its own, put `TEST_ENV_NUMBER` into the name.
