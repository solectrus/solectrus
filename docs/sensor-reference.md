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
# :watt, :celsius, :unitless, :percent, :gram, :euro, :euro_per_kwh

# Boolean unit → true/false
# Accepts for true: 1, '1', 'true', 'on', 'yes'
# Accepts for false: 0, '0', 'false', 'off', 'no', nil

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

All unit types are validated in `Sensor::Definitions::Base::VALID_UNITS`:

```ruby
VALID_UNITS = %i[
  watt          # Power/Energy (automatic W/kW/MW or Wh/kWh/MWh)
  celsius       # Temperature in °C
  percent       # Percent (0-100)
  unitless      # Dimensionless numbers (COP, etc.)
  boolean       # Yes/No
  string        # Text (status messages)
  gram          # Mass/CO2 (automatic g/kg/t)
  euro          # Currency (dynamic precision)
  euro_per_kwh  # Electricity price
].freeze
```

Invalid units cause an `ArgumentError` during loading.

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
celsius: 1       # 23.5 °C
watt: 0          # 2,500 W (for small values)
watt: 1          # 2.5 kW (for kW/MW)
gram: 0          # 500 kg
euro: 2          # 5.23 € (< 10 EUR)
euro: 0          # 1,235 € (>= 10 EUR)
euro_per_kwh: 4  # 0.2523 €/kWh
percent: 0       # 85 %

# Overridable
Sensor::ValueFormatter.new(value, unit: :watt, precision: 2)
```

## DSL Reference

The DSL in `Sensor::Definitions::Dsl` provides the following methods:

### `value` - Base Definition

```ruby
value unit: :watt,              # Required: Unit type
      range: (0..),             # Optional: Value range (for clamping)
      category: :inverter,      # Optional: Category
      nameable: true            # Optional: User-nameable
```

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
  sensor1 + sensor2
end

# Makes the sensor a "calculated sensor"
# Dependencies are automatically passed as keyword arguments
```

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

# Dynamic color (block)
color do |index|
  { background: backgrounds[index - 1], text: COLOR_TEXT }
end
```

### `icon` - Icon Definition

```ruby
# Static icon
icon 'fa-sun'

# Dynamic icon (block)
icon do |data|
  data.positive? ? 'fa-arrow-up' : 'fa-arrow-down'
end
```

### `chart` - Chart Integration

```ruby
# Chart
chart { |timeframe| Sensor::Chart::MyChart.new(timeframe:) }

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

### `aggregations` - Aggregation Definition

```ruby
aggregations stored: [:sum, :max],   # Saved in SummaryValue
             computed: [:avg],       # Calculable via allowed_aggregations
             meta: %i[sum max min avg], # For SQL meta-aggregations
             top10: true             # Enable Top10 ranking

# Can be defined individually:
summary_aggregations :sum, :max        # stored
allowed_aggregations :avg              # computed
summary_meta_aggregations :sum, :avg   # meta
```

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
```

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
  value unit: :percent

  depends_on :grid_import_power, :total_consumption

  calculate do |grid_import_power:, total_consumption:, **|
    return unless total_consumption&.positive?
    return unless grid_import_power

    raw = (total_consumption - grid_import_power) * 100 / total_consumption
    [raw.round, 0].max
  end
end
```

### Example: Total Consumption (Nested)

```ruby
class Sensor::Definitions::TotalConsumption < Sensor::Definitions::Base
  value unit: :watt

  depends_on :house_power, :wallbox_power, :heatpump_power

  calculate do |house_power:, wallbox_power:, heatpump_power:, **|
    (house_power || 0) + (wallbox_power || 0) + (heatpump_power || 0)
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
class Sensor::Definitions::HousePowerPv < Sensor::Definitions::Base
  value unit: :watt, category: :consumer

  # Dependencies differ based on context
  depends_on do |context: :unknown|
    if context == :sql
      # SQL has already applied exclusions in the database
      [:house_power]
    else
      # InfluxDB needs all sensors for manual exclusion
      [:house_power, *Sensor::Config.house_power_excluded_sensors.map(&:name)]
    end
  end

  calculate do |house_power:, **values|
    excluded_power = Sensor::Config.house_power_excluded_sensors.sum do |sensor|
      values[sensor.name] || 0
    end

    [house_power - excluded_power, 0].max
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

Finance sensors inherit from `Sensor::Definitions::FinanceBase` and implement **dual-backend calculations**:

```ruby
class Sensor::Definitions::GridCosts < Sensor::Definitions::FinanceBase
  value

  color background: 'bg-red-500 dark:bg-red-700',
        text: 'text-red-100 dark:text-red-400'

  depends_on :grid_import_power

  chart { |timeframe| Sensor::Chart::GridCosts.new(timeframe:) }
  aggregations stored: false, computed: [:sum], meta: [:sum], top10: true
  trend

  def required_prices
    [:electricity]
  end

  # SQL calculation: Only SELECT expression (embedded in query)
  def sql_calculation
    'COALESCE(grid_import_power_sum,0) * pb_eur_per_kwh / 1000.0'
  end

  # InfluxDB calculation: Ruby implementation with prices
  def calculate_with_prices(grid_import_power:, prices:)
    return unless grid_import_power

    electricity_price = prices[:electricity]
    grid_import_power * electricity_price / 1000.0
  end
end
```

### Dual-Backend Architecture

Finance sensors must implement **both** calculation methods:

1. **`sql_calculation`** - For SQL/SummaryValues queries (daily+)
2. **`calculate_with_prices`** - For InfluxDB queries (hourly)

**Why dual backends?**

- **Hourly data** (P1H-P99H): Calculated live from InfluxDB via `calculate_with_prices`
- **Daily+ data**: Pre-calculated in SQL via `sql_calculation` (performance!)

### SQL Calculation

The `sql_calculation` method returns only the **SELECT expression** (not complete SQL). The query builder embeds this into a complete statement:

```sql
-- Automatically generated from sql_calculation
SELECT
  COALESCE(grid_import_power_sum,0) * pb_eur_per_kwh / 1000.0 AS grid_costs
FROM ...
WHERE timeframe = ...
```

**Available columns** (directly accessible in sql_calculation):

- `{sensor}_sum`, `{sensor}_max`, `{sensor}_min`, `{sensor}_avg` - Aggregated sensor values
- `pb_eur_per_kwh` - Electricity Price (purchase price)
- `pf_eur_per_kwh` - Feed-in Price (feed-in tariff)

### InfluxDB Calculation

The `calculate_with_prices` method receives:

**Parameters:**

- `dependencies:` - Hash with sensor values from dependencies
- `prices:` - Hash with current prices (`:electricity` and `:feed_in` keys with Price objects)

**Returns:** Calculated value in Euro

```ruby
def calculate_with_prices(grid_import_power:, prices:)
  return unless grid_import_power

  electricity_price = prices[:electricity]

  # Convert Wh to kWh and multiply by price
  grid_import_power * electricity_price / 1000.0
end
```

### Helper Methods

**Available in FinanceBase:**

- `electricity_price` → `'pb.eur_per_kwh'` (for SQL)
- `feed_in_price` → `'pf.eur_per_kwh'` (for SQL)
- `to_kwh(wh_expression)` → Converts Wh to kWh (for SQL)
- `greatest(expression, fallback)` → GREATEST SQL function
- `coalesce(expression, fallback)` → COALESCE SQL function

### Finance Sensor as Dependency

Finance sensors can be used as dependencies in calculated sensors:

```ruby
class Sensor::Definitions::TotalCosts < Sensor::Definitions::Base
  value unit: :euro, category: :economic

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

**Available features:**

- `:car` - Car/Wallbox extended
- `:heatpump` - Heat pump
- `:power_splitter` - Grid/PV split
- `:custom_consumer` - Custom power sensors
- `:multi_inverter` - Multiple inverters
- `:finance_charts` - Financial charts
- `:finance_top10` - Financial Top10 rankings

## Ranking System

Top10 rankings for sensors:

```ruby
# Daily ranking (best 10 days)
ranking = Sensor::Query::Ranking.new(:inverter_power, calc_type: :sum)
ranking.days
# => { Date1 => 25000.0, Date2 => 24500.0, ... }

# Monthly ranking
ranking.months
# => { Date1 => 750000.0, Date2 => 720000.0, ... }

# Different aggregations
Sensor::Query::Ranking.new(:outdoor_temp, calc_type: :max).days  # Hottest days
Sensor::Query::Ranking.new(:outdoor_temp, calc_type: :min).days  # Coldest days
```

Supports all sensors with `allowed_aggregations`. Use `top10_permitted` to gate access in the UI.

## Summarizer System

The summarizer system stores aggregated values in `summary_values`:

```ruby
# Summarizer runs synchronously
# Accepts either a Date or a Timeframe
Sensor::Summarizer.call(date)          # Single date
Sensor::Summarizer.call(timeframe)     # Multiple dates in timeframe

# Stores for each sensor with summary_aggregations:
# - sum_inverter_power
# - max_inverter_power
# - min_case_temp
# - avg_autarky (meta-aggregation via SQL)
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
    expect(Sensor::Registry.all.count).to be > 80
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
  it 'formats watt values' do
    component = SensorValue::Component.new(2500, :inverter_power)
    expect(component.value).to eq('2.5')
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
  q.avg :autarky  # SQL: SELECT AVG(value) FROM summary_values WHERE ...
end.call
```

### 4. Dependency Caching

Dependencies are resolved once and cached:

```ruby
sensor = Sensor::Registry[:autarky]
sensor.dependencies  # Cached after first call
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

# 3. Add localization
# config/locales/en.yml
sensors:
  my_sensor: "My Sensor"
  my_sensor_short: "My"

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

```ruby
# Override standard formatting
class Sensor::Definitions::MySensor < Sensor::Definitions::Base
  value unit: :watt

  # Custom precision
  def formatter_options
    { precision: 3 }
  end
end

# Or in view
<%= render SensorValue::Component.new(data, :my_sensor, precision: 3) %>
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
#    Must be one of: watt, celsius, percent, unitless, boolean, string, gram, euro, euro_per_kwh

# Fix: Use a valid unit from VALID_UNITS
```

### Dependencies Not Found

```ruby
# => ArgumentError: Unconfigured sensor: my_dependency

# Checks:
# 1. Dependency configured (ENV variable)?
# 2. Dependency has permitted? = true?
# 3. Dependency exists in registry?
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
