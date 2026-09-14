# Sensor System - Technical Reference

Detailed technical documentation for the SOLECTRUS Sensor System.

## Table of Contents

- [Data Container Details](#data-container-details)
  - [Single Validation](#single-validation)
  - [Series Validation](#series-validation)
  - [Type Conversion](#type-conversion)
- [Unit Types and Formatting](#unit-types-and-formatting)
  - [Available Unit Types](#available-unit-types)
  - [Automatic Scaling](#automatic-scaling)
  - [Precision Rules](#precision-rules)
- [DSL Reference](#dsl-reference)
- [Calculated Sensors](#calculated-sensors)
- [Finance Sensors](#finance-sensors)
- [Permissions and Sponsor Features](#permissions-and-sponsor-features)
- [Ranking System](#ranking-system)
- [Summarizer System](#summarizer-system)
- [Testing](#testing)
- [Performance Optimizations](#performance-optimizations)
- [Common Patterns](#common-patterns)
- [Troubleshooting](#troubleshooting)
- [Further Documentation](#further-documentation)

> 📖 **See also:** [Sensor Overview](sensor-overview.md) for an introduction and [SQL Queries](sensor-sql-queries.md) for detailed SQL examples

## Data Container Details

### Single Validation

`Sensor::Data::Single` validates input data and access patterns:

**Validation rules:**

- Only accepts Hash as `raw_data`
- Keys must be either Symbol (simple value) or Array with 2-3 elements
- For Array keys: First element must be Symbol (sensor name)
- Additional elements must be `:sum`, `:avg`, `:min`, or `:max`
- When multiple aggregations exist for the same sensor, explicit specification is required

```ruby
# Error: Multiple aggregations without explicit specification
data = Sensor::Data::Single.new(
  {
    [:case_temp, :min] => 20,
    [:case_temp, :max] => 35
  },
  timeframe: Timeframe.new("2025-01-15")
)
data.case_temp
# => ArgumentError: Sensor 'case_temp' has multiple aggregations.
#    Use explicit aggregation parameters.

# Correct: Explicit specification
data.case_temp(:min)  # => 20
data.case_temp(:max)  # => 35
```

### Series Validation

`Sensor::Data::Series` has stricter validation:

**Validation rules:**

- Only accepts Hash as `raw_data`
- Keys must be Arrays with exactly 3 elements
- First element: Symbol (sensor name)
- Second and third elements: `:sum`, `:avg`, `:min`, or `:max`
- Values must be Hash with Date or Time keys
- **Always** requires 2 aggregation parameters when accessing data

```ruby
# Error: Without parameters
data.house_power
# => ArgumentError: Series data requires exactly 2 aggregation parameters.
#    Available: house_power(:sum, :sum)

# Correct: With both parameters
data.house_power(:sum, :sum)  # => Hash with Date => Float
```

### Type Conversion

Both data classes perform automatic type conversion based on the sensor unit:

```ruby
# Numeric units → Float
# :watt, :celsius, :unitless, :percent, :gram, :money, :money_per_kwh

# Boolean unit → true/false
# Accepts for true: 1, '1', 'true', 'on', 'yes'
# Accepts for false: 0, '0', 'false', 'off', 'no', ''
# nil stays nil

# String unit → String
# Any text is returned as string
```

**Important notes:**

- **Timeframe is required**: Both classes require a `timeframe` parameter
- **Optional time parameter**: Can be passed for timestamps on current values
- **Series always needs meta-aggregation**: `Series` always requires both aggregation parameters
- **Single allows default access**: `Single` can be called without parameters if only one aggregation exists

## Unit Types and Formatting

### Available Unit Types

Each unit is a class under `app/lib/sensor/units/`. The registry in
`Sensor::Units` maps the unit name to that class, and `Sensor::Units.names`
lists every name a sensor may declare:

```ruby
Sensor::Units.names
# => [:watt,          # Power/Energy (automatic W/kW/MW or Wh/kWh/MWh)
#     :gram,          # Mass/CO2 (automatic g/kg/t)
#     :money,         # Currency (dynamic precision)
#     :money_per_kwh, # Electricity price
#     :celsius,       # Temperature in °C
#     :percent,       # Percent (0-100)
#     :unitless,      # Dimensionless numbers (COP, etc.)
#     :boolean,       # Yes/No
#     :string]        # Text (status messages)
```

`Sensor::Definitions::Base#validate_unit!` checks the unit of every definition
against that list when the registry loads. An invalid unit raises an
`ArgumentError`.

Everything that depends on the unit lives in the unit class: how a value is
scaled, how it is labeled, and how many decimals it deserves. A sensor can
override `#exact_precision` to change the last one.

### Automatic Scaling

Watt and Gram scale automatically:

```ruby
# Watt (context: :rate)
2500 W      => "2.5 kW"
1_500_000 W => "1.5 MW"

# Watt (context: :total)
2500 Wh      => "2.5 kWh"
1_500_000 Wh => "1.5 MWh"

# Gram
500_000 g      => "500 kg"
1_500_000 g    => "1.5 t"
```

### Precision Rules

```ruby
# Default precision per unit
celsius: 1        # 23.5 °C
watt: 0           # 2,500 W (unscaled), and 250 kW (scaled but >= 100)
watt: 1           # 2.5 kW (scaled and < 100)
gram: 0           # 500 g and 500 kg
gram: 1           # 1.5 t (only the tonne step scales far enough)
money: 2          # 5.23 € (< 10)
money: 0          # 1,235 € (>= 10)
money_per_kwh: 4  # 0.2523 €/kWh
percent: 0        # 85 %

# Overridable
Sensor::ValueFormatter.new(value, unit: :watt, precision: 2)
```

A scaled value keeps one decimal only while the printed number stays below a
hundred. `Sensor::Units::Base#decimal_while_short` decides that, so a big
number never carries a decimal that says nothing.

## DSL Reference

The DSL in `Sensor::Definitions::Dsl` provides the following methods:

### `value` - Base Definition

```ruby
value unit: :watt,              # Required: Unit type
      range: (0..),             # Optional: Value range (for clamping)
      category: :inverter,      # Optional: Category (default: :other)
      nameable: true            # Optional: User-nameable
```

`range` is enforced. Every result of a `calculate` block passes through
`#clamp_value`, so a declared bound holds without the block repeating it. A
sensor with `unit: :percent` gets `(0..100)` even when it declares no range.

### `max_age` - Staleness Limit

```ruby
max_age 2.hours   # Default: Sensor::Definitions::Dsl::DEFAULT_MAX_AGE (15 minutes)
```

A "latest" reading older than `max_age` counts as stale. The current stats hide
it. Override this for a sensor that reports rarely. `car_battery_soc` does,
because a car only reports while it is awake.

### `depends_on` - Dependencies

```ruby
# Static
depends_on :sensor1, :sensor2

# Dynamic (block)
depends_on { [:sensor1] if Sensor::Config.something? }

# Conditional
depends_on :sensor1, if: -> { ApplicationPolicy.feature? }
```

### `calculate` - Calculation Logic

```ruby
calculate do |sensor1:, sensor2:, **|
  return unless sensor1 && sensor2

  sensor1 + sensor2
end

# Makes the sensor a "calculated sensor"
# Dependencies are automatically passed as keyword arguments
```

The block becomes a method of the sensor rather than a lambda, and three things
follow from that:

- `return unless ...` works as a guard, the way it reads.
- A dependency the caller left out raises `ArgumentError` instead of binding
  `nil` silently, because the keywords are required.
- Always close the trailing `**`. Without it, an extra dependency raises too.

The result then passes through `#clamp_value`, so a declared `range` holds
whatever the block returned.

### `color` - Color Definition

```ruby
# Static color (required: bg and text)
color background: 'bg-sensor-pv',
      text: 'text-white dark:text-slate-400'

# Gradient color (required: from/to, start/stop)
color background: gradient(
        from: -10,
        to: 40,
        start: 'bg-sky-400 dark:bg-sky-600',
        stop: 'bg-red-400 dark:bg-red-600',
      ),
      text: 'text-red-100 dark:text-red-300'

# Static color with the optional extras: a border class, and hatch_fill to
# draw the bars of the chart hatched (the forecast uses it)
color background: 'bg-sensor-pv',
      text: 'text-white dark:text-slate-400',
      border: 'border-emerald-200 dark:border-emerald-900',
      hatch_fill: true

# Dynamic color (block)
color do |index|
  { background: backgrounds[index - 1], text: COLOR_TEXT }
end
```

The block takes one argument. It is the value where the caller has one, for
example the percentage behind a radial badge, and the index otherwise, for
example the position of a custom consumer. The block returns a hash with
`:background` and `:text`, and `:border` if it has one.

### `icon` - Icon Definition

```ruby
# Static icon
icon 'fa-sun'

# Dynamic icon (block)
icon do |data|
  value = data.respond_to?(:battery_soc) ? data.battery_soc : nil

  case value
  when 0...15 then 'fa-battery-empty'
  when 61...85 then 'fa-battery-three-quarters'
  else 'fa-battery-half'
  end
end
```

The block receives the whole `Sensor::Data` object, not a number, and it can be
`nil`. Read your own sensor off it behind a `respond_to?` guard, the way
`battery_soc` does, because the container holds only the sensors that query
loaded. The reader is `sensor.icon(data:)`, a keyword argument:
`SensorIcon::Component` calls it that way.

### `chart` - Chart Integration

```ruby
# Chart
chart { |timeframe| Sensor::Chart::MyChart.new(timeframe:) }

# A combined chart that a page offers under other names. `entries:` names the
# sensors a page lists instead of this one, and the URL carries that name.
chart(entries: %i[grid_import_power grid_export_power]) do |timeframe|
  Sensor::Chart::GridPower.new(timeframe:)
end

# Scatter chart (define as separate sensor if needed)
# class Sensor::Definitions::MyScatterSensor < Sensor::Definitions::Base
#   value unit: :unitless, category: :other
#   depends_on :outdoor_temp
#   chart { |timeframe| Sensor::Chart::MyScatterChart.new(timeframe:) }
#   calculate { nil }
# end
#
# Access chart
sensor.chart(timeframe)                      # Returns chart
```

### `chart_only` - Sensor Without a Value

```ruby
chart_only
```

A chart-only sensor exists to drive a chart. The chart composes what it shows
from other sensors, so the sensor itself reads `null` in every timeframe.
`chart_only` declares that intent and installs `calculate { nil }`. Declare it
instead of letting a consumer guess: `power_balance` has no dependencies, and
`heatpump_cop_scatter` depends on three sensors, but neither has a value of its
own.

### `home_pages` - Where the Chart Appears

```ruby
# Static: the pages that offer a chart of this sensor
home_pages :balance, :inverter

# Dynamic: a block runs on the sensor and returns the same list
home_pages { Sensor::Config.total_consumption_relevant? ? [:balance] : [] }
```

The order is the order a link prefers. `house_power` is a system total on the
power balance and the subject of the house page, so a link goes to the balance.
A sensor without a declaration is on no page. `Sensor::HomePage` collects the
answers for the controller, for `SensorPathHelper` and for the chart dropdown.

### `aggregations` - Aggregation Definition

```ruby
aggregations stored: [:sum, :max],   # Saved in SummaryValue
             computed: [:avg],       # Exposed via allowed_aggregations
             meta: %i[sum max min avg], # Available meta-aggregations for summarized data
             top10: true             # Enable Top10 ranking

# Can be defined individually:
summary_aggregations :sum, :max        # stored
allowed_aggregations :avg              # computed
summary_meta_aggregations :sum, :avg   # meta
```

In practice, `allowed_aggregations` is the public capability list used by `Sensor::Query::Total`, `Sensor::Query::Ranking`, and trend handling. `summary_meta_aggregations` describes which meta-aggregations exist for summarized data, but it is not the primary validation hook for the DSL.

### `requires_permission` - Permission Check

```ruby
requires_permission :car  # ApplicationPolicy.feature_enabled?(:car)

# Alternative with block
permitted { ApplicationPolicy.custom_check? }
```

### `trend` - Trend Tracking

```ruby
trend more_is_better: true   # Rising values = better
trend more_is_better: false  # Falling values = better
trend                        # Default: more_is_better: false
trend aggregation: :avg      # Default: :sum
```

### Naming and Description

Neither the display name nor the description comes from the DSL. Both live in
`Sensor::Definitions::Describable`, which reads them from I18n so they stay
bilingual:

```ruby
sensor.display_name          # => "Generation"   (config/locales: sensors.inverter_power)
sensor.display_name(:short)  # => sensors.inverter_power_short, falling back to the long name
sensor.description           # => config/locales: sensor_descriptions.inverter_power
```

A user-defined name in `Setting.sensor_names` wins over both. The systematic
variants (the `_grid`, `_pv` and `_total` suffixes, and the `custom_*`
families) are composed from translatable fragments, so they need no key of
their own.

## Calculated Sensors

### Concept

Calculated sensors define:

1. **Dependencies**: Which sensors are required?
2. **Calculate block**: How is the value calculated?

The query system:

- Resolves dependencies recursively
- Loads all required raw sensors
- Executes calculations in topological order

### Example: Autarky (Simple)

```ruby
class Sensor::Definitions::Autarky < Sensor::Definitions::Base
  value unit: :percent, range: (0..100)

  depends_on :grid_import_power, :total_consumption

  calculate do |grid_import_power:, total_consumption:, **|
    return unless total_consumption
    return if total_consumption.zero?
    return unless grid_import_power

    (total_consumption - grid_import_power) * 100.0 / total_consumption
  end
end
```

### Example: Total Consumption (Nested)

```ruby
class Sensor::Definitions::TotalConsumption < Sensor::Definitions::Base
  value unit: :watt, range: (0..)

  # A consumer that is not configured is left out, so the calculate block
  # never waits for a sensor that cannot report. The real definition also adds
  # back the custom consumers that house_power excludes.
  depends_on do
    [
      :house_power,
      (:heatpump_power if Sensor::Config.configured?(:heatpump_power)),
      (:wallbox_power if Sensor::Config.configured?(:wallbox_power)),
    ].compact
  end

  # Stay nil (not 0) when no consumer has data, so an empty period renders as
  # a gap instead of a misleading 0 baseline.
  calculate do |house_power:, wallbox_power: nil, heatpump_power: nil, **|
    values = [house_power, wallbox_power, heatpump_power].compact
    values.sum unless values.empty?
  end
end
```

Autarky uses `total_consumption`, the system automatically resolves:

```
autarky
  ├─ grid_import_power (raw)
  └─ total_consumption (calculated)
      ├─ house_power (raw)
      ├─ wallbox_power (raw)
      └─ heatpump_power (raw)
```

### Dynamic Dependencies

Dependencies can be dynamic based on configuration:

```ruby
class Sensor::Definitions::InverterPower < Sensor::Definitions::Base
  depends_on do
    # Only dependent if inverter_power is not directly configured
    Sensor::Config.configured?(:inverter_power) ? [] : [:inverter_power_total]
  end

  calculate do |inverter_power: nil, inverter_power_total: nil, **|
    inverter_power || inverter_power_total
  end
end
```

### Context-Based Dependencies

Dependencies can differ based on query context (`:influx` vs `:sql`):

```ruby
class Sensor::Definitions::HousePower < Sensor::Definitions::Base
  value unit: :watt, range: (0..), category: :consumer, nameable: true

  # Dependencies differ based on context
  depends_on do |context: :unknown|
    if context == :sql
      # SQL has already applied exclusions in the database
      [:house_power]
    else
      # InfluxDB needs all excluded sensors for manual exclusion
      [:house_power, *Sensor::Config.house_power_excluded_sensors.map(&:name)]
    end
  end

  # The context reaches the calculate block too
  calculate do |house_power:, context: :unknown, **excluded_sensor_values|
    return unless house_power
    return house_power if context == :sql

    excluded_total =
      excluded_sensor_values
        .slice(*Sensor::Config.house_power_excluded_sensors.map(&:name))
        .values
        .compact
        .sum

    house_power - excluded_total
  end
end
```

**Why context matters:**

- **SQL context**: Dependencies are already filtered/processed in the database query
- **InfluxDB context**: All raw sensors needed for Ruby-side calculation
- **Unknown context**: Fallback to most conservative (complete) dependency set

**Context is passed automatically by:**

- `Sensor::Query::Helpers::Influx::Total` → `:influx`
- `Sensor::Query::Helpers::Sql::Total` → `:sql`

## Finance Sensors

Finance sensors inherit from `Sensor::Definitions::FinanceBase` and typically implement **dual-backend calculations**:

```ruby
class Sensor::Definitions::GridCosts < Sensor::Definitions::FinanceBase
  value

  color background: 'bg-sensor-costs',
        text: 'text-white dark:text-red-200'

  depends_on :grid_import_power

  home_pages :balance

  chart { |timeframe| Sensor::Chart::GridCosts.new(timeframe:) }
  aggregations stored: false, computed: [:sum], meta: %i[sum min max], top10: true
  trend

  def required_prices
    [:electricity]
  end

  # SQL calculation: Only SELECT expression (embedded in query)
  def sql_calculation
    'COALESCE(grid_import_power_sum,0) * pb_money_per_kwh / 1000.0'
  end

  # InfluxDB calculation: Ruby implementation with prices
  def calculate_with_prices(grid_import_power:, prices:)
    return unless grid_import_power

    electricity_price = prices[:electricity]
    return unless electricity_price

    grid_import_power * electricity_price / 1000.0
  end
end
```

### Dual-Backend Architecture

A `FinanceBase` subclass needs two calculations, one per backend:

1. **`sql_calculation`** - For SQL/SummaryValues queries (daily+)
2. **`calculate_with_prices`** - For InfluxDB queries (hourly)

The second one is for a sensor that turns power into money on its own. A
`FinanceBase` sensor that carries a regular `calculate` block instead is summed
from its dependencies like any other sensor, and needs no
`calculate_with_prices`: `Influx::FinanceCalculation` skips it as soon as
`calculated?` answers true. `total_costs` is that case, adding `grid_costs` and
`opportunity_costs`.

`sql_calculation` is not limited to `FinanceBase`. Six sensors inherit from
`Sensor::Definitions::Base` and still contribute a SQL expression: `autarky`,
`self_consumption_quote`, `heatpump_cop`, `co2_reduction`, `solar_price` and
`savings`. They keep their regular `calculate` block for the InfluxDB path and
for post-processing.

**Why dual backends?**

- **Hourly data** (P1H-P99H): Calculated live from InfluxDB via `calculate_with_prices`
- **Daily+ data**: Pre-calculated in SQL via `sql_calculation` (performance!)

### SQL Calculation

The `sql_calculation` method returns only the **SELECT expression** (not complete SQL). The query builder embeds this into a complete statement:

```sql
-- Automatically generated from sql_calculation
SELECT
  COALESCE(grid_import_power_sum,0) * pb_money_per_kwh / 1000.0 AS grid_costs
FROM ...
WHERE timeframe = ...
```

**Available columns** (directly accessible in sql_calculation):

- `{sensor}_sum`, `{sensor}_max`, `{sensor}_min`, `{sensor}_avg` - Aggregated sensor values
- `pb_money_per_kwh` - Electricity Price (purchase price)
- `pf_money_per_kwh` - Feed-in Price (feed-in tariff)

### InfluxDB Calculation

The `calculate_with_prices` method receives:

**Parameters:**

- Dependency values are passed as keyword arguments (for example `grid_import_power:` or `house_power:`)
- `prices:` contains the currently loaded prices (for example `:electricity` and `:feed_in`)

**Returns:** Calculated value in the configured currency

```ruby
def calculate_with_prices(grid_import_power:, prices:)
  return unless grid_import_power

  electricity_price = prices[:electricity]
  return unless electricity_price

  # Convert Wh to kWh and multiply by price
  grid_import_power * electricity_price / 1000.0
end
```

### Helper Methods

**Available in FinanceBase:**

- `to_kwh(wh_expression)` → Converts Wh to kWh (for SQL)
- `greatest(expression, fallback)` → GREATEST SQL function
- `coalesce(expression, fallback)` → COALESCE SQL function

### Finance Sensor as Dependency

Finance sensors can be used as dependencies in calculated sensors:

```ruby
class Sensor::Definitions::TotalCosts < Sensor::Definitions::Base
  value unit: :money, category: :economic

  depends_on :grid_costs, :opportunity_costs  # Finance sensors as dependencies

  calculate do |grid_costs:, opportunity_costs:, **|
    grid_costs + opportunity_costs
  end
end
```

> 💡 **More details:** SQL query examples with finance sensors can be found in [sensor-sql-queries.md](sensor-sql-queries.md#cost-calculation-with-price-join)

## Permissions and Sponsor Features

Sensors can be tied to sponsor features:

```ruby
class Sensor::Definitions::CarBatterySoc < Sensor::Definitions::Base
  requires_permission :car  # Only for sponsors with :car feature
end

class Sensor::Definitions::HeatpumpPower < Sensor::Definitions::Base
  requires_permission :heatpump
end

# Top10 permissions (independent from sensor visibility)
class Sensor::Definitions::TotalCosts < Sensor::Definitions::FinanceBase
  top10_permitted { ApplicationPolicy.finance_top10? }
end
```

**Feature check:**

```ruby
Sensor::Registry[:car_battery_soc].permitted?  # => true/false
Sensor::Config.exists?(:car_battery_soc)       # => false if not permitted
```

**All sponsor features**, from the `SPONSOR_FEATURES` list inside
`ApplicationPolicy` (a `private_constant`, so read it there). Each one gets a
class-level predicate, for example `ApplicationPolicy.heatpump?`:

| Feature                | Meaning                              |
| ---------------------- | ------------------------------------ |
| `:power_splitter`      | Grid/PV split                        |
| `:themes`              | Color themes                         |
| `:car`                 | Car/Wallbox extended                 |
| `:custom_consumer`     | Custom power sensors                 |
| `:multi_inverter`      | Multiple inverters                   |
| `:relative_timeframe`  | Relative timeframes (P7D, P30D, ...) |
| `:insights`            | Figures and trends behind a chart    |
| `:heatpump`            | Heat pump                            |
| `:finance_charts`      | Financial charts                     |
| `:power_balance_chart` | Power balance chart                  |
| `:finance_top10`       | Financial Top10 rankings             |
| `:mcp`                 | AI access (see [MCP](MCP.md))        |
| `:amortization`        | Amortization calculator              |

Sensor definitions name only `:car`, `:heatpump` and `:power_splitter` through
`requires_permission`, plus `:finance_top10` through `top10_permitted`. Charts
gate themselves with `permitted_feature_name`, and the rest gate UI elsewhere.

## Ranking System

Top10 rankings for sensors:

```ruby
# Daily ranking (best 10 days)
ranking = Sensor::Query::Ranking.new(:inverter_power, aggregation: :sum, period: :day)
ranking.call
# => [{ date: Date1, value: 25000.0 }, { date: Date2, value: 24500.0 }, ...]

# Monthly ranking
Sensor::Query::Ranking.new(:inverter_power, aggregation: :sum, period: :month).call

# Different aggregations
Sensor::Query::Ranking.new(:outdoor_temp, aggregation: :max, period: :day).call  # Hottest days
Sensor::Query::Ranking.new(:outdoor_temp, aggregation: :min, period: :day, desc: false).call  # Coldest days
```

Options and their defaults: `aggregation: :sum`, `period: :day`, `desc: true`,
`limit: 10`, plus `start` and `stop` to narrow the range. `period` accepts
`:day`, `:week`, `:month` and `:year`; anything else raises. `aggregation` is
checked against the `allowed_aggregations` of the sensor, so a sensor that
cannot answer for it raises instead of returning an empty list. Use
`top10_permitted` to gate access in the UI.

`#complete_periods_only?` says whether the ranking dropped the periods its
range only cuts into. It does so in two cases, and both are about a fragment
winning for being one:

- An **ascending** ranking (`desc: false`), where a period that has barely
  started takes the lowest spot on the strength of its own length.
- An **averaged** aggregation in either direction, because an average is not
  smaller for covering less. A sunny half-month outranks every whole one.

The flag follows from the aggregation rather than from a per-sensor opt-in, so
`outdoor_temp` and `battery_soc` are covered the same way the two ratios are. A
caller that presents the ranking reads it to say that the list covers a
narrower span than the range it asked for.

## Summarizer System

The summarizer system stores aggregated values in `summary_values`:

```ruby
# Summarizer runs synchronously
# Accepts a Date, a Range of dates or a Timeframe
Sensor::Summarizer.call(date)          # Single date
Sensor::Summarizer.call(date1..date2)  # Every date in the range
Sensor::Summarizer.call(timeframe)     # The missing or stale days of the timeframe

# Anything else raises an ArgumentError, and so does Timeframe.now

# Stores records in `summary_values` for each configured sensor/aggregation pair:
# - field: "inverter_power", aggregation: "sum"
# - field: "inverter_power", aggregation: "max"
# - field: "case_temp", aggregation: "min"
#
# Meta-aggregations such as `AVG` over daily values are computed later by SQL queries
```

**Only sensors with `summary_aggregations` are stored:**

```ruby
class Sensor::Definitions::InverterPower < Sensor::Definitions::Base
  aggregations stored: [:sum, :max]  # Saved in Summary
end

class Sensor::Definitions::Autarky < Sensor::Definitions::Base
  aggregations stored: false, computed: [:avg], meta: [:avg]  # Not stored, but calculable
end
```

## Testing

### Registry Tests

```ruby
RSpec.describe Sensor::Registry do
  it 'loads all sensor definitions' do
    expect(Sensor::Registry.all).not_to be_empty
  end

  it 'finds sensor by name' do
    sensor = Sensor::Registry[:inverter_power]
    expect(sensor.unit).to eq(:watt)
  end
end
```

### Query Tests

```ruby
RSpec.describe Sensor::Query::Total do
  it 'fetches single values with DSL' do
    data = Sensor::Query::Total.new(Timeframe.day) do |q|
      q.sum :inverter_power
    end.call

    expect(data.inverter_power).to be_a(Numeric)
  end
end
```

### Component Tests

```ruby
RSpec.describe SensorValue::Component do
  subject(:component) { SensorValue::Component.new(2500, :inverter_power) }

  it 'formats watt values' do
    expect(component.integer_part).to eq('2')
    expect(component.decimal_part).to eq('5') # separator is exposed on its own
    expect(component.unit).to eq('kW')
  end
end
```

## Performance Optimizations

### 1. Registry Caching

```ruby
# Definitions are loaded once and cached
Sensor::Registry.all  # Loads all definitions
Sensor::Registry.all  # Uses cache (fast!)

# Automatically reset in development on code changes
Rails.application.reloader.to_prepare do
  Sensor::Registry.reset!
end
```

### 2. Flux Query Optimization

InfluxDB queries use:

- Filter on measurement/field
- Range restriction to timeframe
- Aggregations in Flux (not in Ruby)

### 3. SQL Meta-Aggregations

```ruby
# Instead of: Load all values and calculate in Ruby
# Use: SQL aggregation on summary_values
Sensor::Query::Total.new(Timeframe.year) do |q|
  q.avg :case_temp, :min  # SQL: SELECT AVG(case_temp_min) FROM daily
end.call
```

### 4. Dependency Resolution

Dependencies are resolved centrally via `Sensor::DependencyResolver`:

```ruby
resolver = Sensor::DependencyResolver.new([:autarky], context: :sql)
resolver.resolve
```

## Common Patterns

### Adding a New Sensor

```ruby
# 1. Create definition
# app/lib/sensor/definitions/custom/my_sensor.rb
class Sensor::Definitions::MySensor < Sensor::Definitions::Base
  value unit: :watt, category: :custom

  aggregations stored: [:sum], top10: true
end

# 2. Set ENV variable (for raw sensors)
INFLUX_SENSOR_MY_SENSOR=measurement:field

# 3. Add localization (en.yml and de.yml, both are shipped)
# config/locales/en.yml
sensors:
  my_sensor: "My Sensor"
  my_sensor_short: "My"       # Optional, falls back to the long name
sensor_descriptions:
  my_sensor: "What this sensor measures"

# 4. Done! Registry loads automatically
Sensor::Registry[:my_sensor]
```

### Adding a Calculated Sensor

```ruby
class Sensor::Definitions::MyCalculation < Sensor::Definitions::Base
  value unit: :percent

  depends_on :sensor1, :sensor2

  calculate do |sensor1:, sensor2:, **|
    return unless sensor1 && sensor2
    (sensor1 * 100.0 / sensor2).round(1)
  end

  aggregations stored: false, computed: [:avg], meta: [:avg]
end

# No ENV needed!
```

### Adding a Chart

```ruby
# 1. Create chart class
# app/lib/sensor/chart/my_chart.rb
class Sensor::Chart::MyChart < Sensor::Chart::Base
  def chart_sensor_names
    [:my_sensor]
  end

  # Optional: Override build_series_data for custom data loading
  # Optional: Override transform_data for custom transformations
  # Optional: Override sql_aggregations_for_sensor for custom aggregations
end

# 2. Link in sensor definition
class Sensor::Definitions::MySensor < Sensor::Definitions::Base
  chart { |timeframe| Sensor::Chart::MyChart.new(timeframe:) }
end
```

### Custom Formatting

The unit decides the precision. Some places must not round, for example a
tooltip. They ask the sensor for `exact_precision`, and a sensor can override
it:

```ruby
class Sensor::Definitions::MySensor < Sensor::Definitions::Base
  value unit: :watt

  def exact_precision
    3
  end
end
```

For a single place, pass the option to the component instead. Every option
except `:class` and `:sign` goes straight to `Sensor::ValueFormatter`:

- `precision:` - decimals, overriding the unit
- `context:` - `:rate` or `:total` (`:auto` asks the unit, and is the default)
- `scaling:` - `:auto`, `:off`, `:kilo`, `:mega`, or a number to divide by.
  Anything else raises.
- `sign:` - print a leading `+` for a positive value

```slim
= render SensorValue::Component.new(data, :my_sensor, precision: 3)
= render SensorValue::Component.new(data, :my_sensor, context: :total)
```

## Troubleshooting

### Sensor Not Found

```ruby
Sensor::Registry[:my_sensor]
# => ArgumentError: Unknown sensor: my_sensor

# Checks:
# 1. Definition file exists?
# 2. Class inherits from Sensor::Definitions::Base?
# 3. Namespace correct?
# 4. Rails server restarted? (in development)
```

### Invalid Unit

```ruby
# => ArgumentError: Invalid unit :kilogram for sensor :my_sensor.
#    Must be one of: watt, gram, money, money_per_kwh, celsius, percent, unitless, boolean, string

# Fix: Use a name from Sensor::Units.names
```

### Sensor Missing Although It Is Defined

A missing dependency raises nothing. A calculated sensor exists only while
every one of its static dependencies exists, so one unconfigured raw sensor
removes it from `Sensor::Config.sensors` without a word:

```ruby
Sensor::Config.exists?(:my_sensor)  # => false

# Ask the dependencies one by one to find the one that answers false
Sensor::Registry[:my_sensor].static_dependencies.map do |dep|
  [dep, Sensor::Config.exists?(dep)]
end

# Checks:
# 1. Dependency configured (INFLUX_SENSOR_* variable)?
# 2. Dependency has permitted? = true? (Sensor::Config.exists?(name, check_policy: false) tells the two apart)
# 3. Dependency exists in registry?
```

### Circular Dependency

```ruby
# => ArgumentError: Circular dependency detected in sensors: [...]

# Sensor::DependencyResolver raises this when the graph has no topological
# order. Fix: break the cycle in the `depends_on` declarations it names.
```

### Chart Not Displayed

```ruby
sensor = Sensor::Registry[:my_sensor]
sensor.chart_enabled?  # => false

# Fix: Add chart block to definition
```

## Further Documentation

- **[Sensor Overview](sensor-overview.md)** - Introduction and core concepts
- **[SQL Queries](sensor-sql-queries.md)** - Detailed SQL query examples
- **Code reference**:
  - `app/lib/sensor/definitions/dsl.rb` - DSL implementation
  - `app/lib/sensor/definitions/base.rb` - Base class
  - `app/lib/sensor/definitions/finance_base.rb` - Finance sensors
  - `app/lib/sensor/chart/base.rb` - Chart integration
  - `spec/lib/sensor/` - Comprehensive tests
