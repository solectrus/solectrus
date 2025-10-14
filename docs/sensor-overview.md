# Sensor System - Overview

An introduction to the SOLECTRUS Sensor System.

## Table of Contents

- [What is the Sensor System?](#what-is-the-sensor-system)
- [Quick Start](#quick-start)
- [Architecture Overview](#architecture-overview)
- [Core Concepts](#core-concepts)
  - [1. Sensor Definitions](#1-sensor-definitions)
  - [2. Registry System](#2-registry-system)
  - [3. Query System](#3-query-system)
  - [4. Data Containers](#4-data-containers)
  - [5. Formatting](#5-formatting)
  - [6. Chart Integration](#6-chart-integration)
  - [7. Configuration](#7-configuration)
- [Further Documentation](#further-documentation)

## What is the Sensor System?

The Sensor System is the central architecture for all measurement values in SOLECTRUS. It provides a unified API for:

- **Sensor Definitions**: Declarative description of 80+ sensors
- **Data Queries**: Unified access to InfluxDB and PostgreSQL
- **Formatting**: Automatic value formatting with units
- **Charts**: Integration into the chart system
- **Calculations**: Automatic dependency resolution for calculated values

## Quick Start

```ruby
# 1. Get sensor information
sensor = Sensor::Registry[:inverter_power]
sensor.unit           # => :watt
sensor.category       # => :inverter
sensor.display_name   # => "Generation"

# 2. Query current values (InfluxDB)
data = Sensor::Query::Influx::Latest.new([:inverter_power]).call
data.inverter_power   # => 2500.0

# 3. Query historical data (SQL with DSL)
data = Sensor::Query::Sql.new do |q|
  q.sum :inverter_power
  q.timeframe Timeframe.today
end.call
data.inverter_power   # => 15000.0 (daily energy in Wh)

# 4. Formatted output in views
<%= render SensorValue::Component.new(data, :inverter_power) %>
# => "2.5 kW"
```

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────┐
│                    View Layer                                │
│  SensorValue::Component  •  Chart Components                 │
└────────────────┬────────────────────────────────────────────┘
                 │
┌────────────────▼────────────────────────────────────────────┐
│              Query Layer                                     │
│  Sensor::Query::Sql  •  Sensor::Query::Influx::*            │
└────────────────┬────────────────────────────────────────────┘
                 │
┌────────────────▼────────────────────────────────────────────┐
│            Definition Layer                                  │
│  Sensor::Registry  •  Sensor::Definitions::*                 │
└────────────────┬────────────────────────────────────────────┘
                 │
┌────────────────▼────────────────────────────────────────────┐
│              Data Layer                                      │
│  Sensor::Data::Single  •  Sensor::Data::Series              │
└─────────────────────────────────────────────────────────────┘
```

### Directory Structure

```
app/lib/sensor/
├── definitions/               # Sensor definitions (80+ sensors)
│   ├── base.rb               # Base class with validation
│   ├── dsl.rb                # DSL for declarative definitions
│   ├── battery/              # Battery sensors
│   ├── car/                  # Electric vehicle sensors
│   ├── custom_consumer/      # Custom Power (1-20)
│   ├── efficiency/           # Autarky, Self-Consumption
│   ├── environment/          # CO2, outdoor temperature
│   ├── finance/              # Costs, savings
│   ├── grid/                 # Grid (import/export)
│   ├── heatpump/             # Heat pump
│   ├── house/                # House consumption
│   ├── inverter/             # Inverter
│   ├── price/                # Electricity prices
│   ├── system/               # System status
│   └── wallbox/              # Wallbox
│
├── query/                    # Data query system
│   ├── base.rb              # Common query logic
│   ├── sql.rb               # PostgreSQL (historical data)
│   ├── influx/              # InfluxDB queries
│   │   ├── base.rb          # Flux query base
│   │   ├── latest.rb        # Current values
│   │   ├── integral.rb      # Energy sums
│   │   ├── aggregation.rb   # Min/Max/Avg
│   │   └── series.rb        # Time series for charts
│   ├── helpers/             # Query builders
│   ├── power_peak.rb        # Peak power
│   └── ranking.rb           # Top10 rankings
│
├── chart/                    # Chart integration
│   ├── base.rb              # Base for all charts
│   ├── inverter_power.rb    # Inverter chart
│   ├── autarky.rb           # Autarky chart
│   └── ...                  # 15+ specialized charts
│
├── data/                     # Data containers
│   ├── base.rb              # Common functionality
│   ├── single.rb            # Single values
│   └── series.rb            # Time series
│
├── config.rb                # Central configuration
├── registry.rb              # Sensor registry (auto-discovery)
├── value_formatter.rb       # Value formatting
├── unit_formatter.rb        # Unit formatting
├── dependency_resolver.rb   # Dependency resolution
├── summarizer.rb            # Summary calculations
├── summary_builder.rb       # Summary creation
└── summary_invalidator.rb   # Cache invalidation

app/components/sensor_value/
├── component.rb             # ViewComponent for sensor values
└── component.html.slim      # Template
```

## Core Concepts

### 1. Sensor Definitions

Sensors are defined declaratively using a DSL:

```ruby
class Sensor::Definitions::InverterPower < Sensor::Definitions::Base
  # Value definition
  value unit: :watt, range: (0..), category: :inverter

  # Color definition
  color hex: '#16a34a',
        bg_classes: 'bg-green-600 dark:bg-green-800/80',
        text_classes: 'text-white dark:text-slate-400'

  # Icon
  icon 'fa-sun'

  # Trend tracking
  trend more_is_better: true

  # Aggregations (stored = saved in Summary, computed = calculable, meta = SQL, top10 = ranking)
  aggregations stored: [:sum, :max], computed: [:sum], meta: %i[sum max min avg], top10: true

  # Chart integration
  chart { |timeframe, variant: nil| Sensor::Chart::InverterPower.new(timeframe:, variant:) }
end
```

**Calculated sensors** define dependencies and calculation logic:

```ruby
class Sensor::Definitions::Autarky < Sensor::Definitions::Base
  value unit: :percent

  color hex: '#15803d',
        bg_classes: 'bg-green-700 dark:bg-green-900',
        text_classes: 'text-green-200 dark:text-green-400'

  # Declare dependencies
  depends_on :grid_import_power, :total_consumption

  # Calculation logic
  calculate do |grid_import_power:, total_consumption:, **|
    return unless total_consumption
    return if total_consumption.zero?
    return unless grid_import_power

    raw = (total_consumption - grid_import_power) * 100 / total_consumption
    [raw.round, 0].max
  end

  chart { |timeframe| Sensor::Chart::Autarky.new(timeframe:) }
  aggregations stored: false, computed: [:avg], meta: [:avg]
end
```

**Template sensors** for Custom Power (1-20):

```ruby
class Sensor::Definitions::CustomPower < Sensor::Definitions::Base
  MAX = 20  # Generates custom_power_01 through custom_power_20

  def initialize(number)
    @number = number
    super()
  end

  value unit: :watt, category: :consumer, nameable: true
  aggregations stored: [:sum], top10: true

  def name
    :"custom_power_#{format('%02d', @number)}"
  end
end
```

> 💡 **More details:** Complete DSL reference can be found in [sensor-reference.md](sensor-reference.md#dsl-reference)

### 2. Registry System

The registry system automatically loads all sensor definitions:

```ruby
# Auto-discovery: Finds all classes under Sensor::Definitions::*
Sensor::Registry.all
# => [#<Sensor::Definitions::InverterPower>, #<Sensor::Definitions::Autarky>, ...]

# Lookup by symbol
Sensor::Registry[:inverter_power]
# => #<Sensor::Definitions::InverterPower>

# Filter by category
Sensor::Registry.by_category(:inverter)
# => [#<Sensor::Definitions::InverterPower>, ...]

# Chart-enabled sensors
Sensor::Registry.chart_sensors
# => [all sensors with chart block]

# Top10-capable sensors
Sensor::Registry.top10_sensors
# => [all sensors with top10: true]
```

**Thread-safe caching**: The registry loads definitions once and caches them.

### 3. Query System

The query system provides unified access to different data sources:

#### 3.1 InfluxDB Queries (Live Data)

```ruby
# Current values (Latest)
data = Sensor::Query::Influx::Latest.new([:inverter_power, :house_power]).call
data.inverter_power  # => 2500.0 (current value)

# Time series for charts (Series)
data = Sensor::Query::Influx::Series.new([:inverter_power], timeframe).call
data.inverter_power  # => [[timestamp1, value1], [timestamp2, value2], ...]

# Aggregations (Min/Max/Avg)
data = Sensor::Query::Influx::Aggregation.new([:case_temp], timeframe).call
data.case_temp  # => { min: 15.2, max: 45.8, avg: 32.1 }

# Energy integrals (Wh)
data = Sensor::Query::Influx::Integral.new([:inverter_power], timeframe).call
data.inverter_power  # => 15000.0 (Wh)
```

#### 3.2 SQL Queries (Historical Data)

SQL queries use a DSL for flexible queries:

```ruby
# Simple aggregation
data = Sensor::Query::Sql.new do |q|
  q.sum :inverter_power
  q.timeframe Timeframe.today
end.call
data.inverter_power  # => 15000.0

# Multiple sensors with different aggregations
data = Sensor::Query::Sql.new do |q|
  q.sum :inverter_power
  q.avg :case_temp, :min   # Average of minima
  q.timeframe Timeframe.new('2025-01')
end.call

# Time series (grouped by day/week/month)
data = Sensor::Query::Sql.new do |q|
  q.sum :inverter_power
  q.timeframe Timeframe.this_week
  q.group_by :day
end.call
data.inverter_power  # => {Date1 => energy1, Date2 => energy2, ...}
```

> 💡 **More details:** Complete SQL query examples with generated SQL can be found in [sensor-sql-queries.md](sensor-sql-queries.md)

#### 3.3 Automatic Dependency Resolution

Calculated sensors automatically resolve dependencies:

```ruby
# Autarky requires: grid_import_power + total_consumption
# total_consumption requires: house_power + wallbox_power + heatpump_power
data = Sensor::Query::Sql.new do |q|
  q.avg :autarky
  q.timeframe Timeframe.this_month
end.call

# All dependencies were automatically loaded and calculated:
data.autarky             # => 85.0 (calculated)
data.total_consumption   # => 1500.0 (calculated)
data.house_power         # => 800.0 (from DB)
data.wallbox_power       # => 500.0 (from DB)
data.heatpump_power      # => 200.0 (from DB)
data.grid_import_power   # => 225.0 (from DB)
```

### 4. Data Containers

All query results are returned in `Sensor::Data` objects. There are two classes:
- `Sensor::Data::Single` for single values
- `Sensor::Data::Series` for time series

#### 4.1 Single Values

```ruby
# Simple values (current)
data = Sensor::Data::Single.new(
  {
    house_power: 500,
    inverter_power: 300,
  },
  timeframe: Timeframe.now
)
data.house_power    # => 500
data.inverter_power # => 300

# Aggregated values (with meta-aggregation)
data = Sensor::Data::Single.new(
  {
    [:house_power, :sum] => 10500,
    [:case_temp, :avg, :min] => 18.5,
  },
  timeframe: Timeframe.today
)
data.house_power(:sum)      # => 10500
data.case_temp(:avg, :min)  # => 18.5
```

#### 4.2 Time Series

```ruby
data = Sensor::Data::Series.new(
  {
    [:house_power, :sum, :sum] => {
      Date.new(2025, 1, 1) => 3750.0,
      Date.new(2025, 2, 1) => 3400.0,
      Date.new(2025, 3, 1) => 3200.0,
    },
  },
  timeframe: Timeframe.new("2025")
)

data.series?  # => true
data.house_power(:sum, :sum)
# => { Date(2025,1,1) => 3750.0, Date(2025,2,1) => 3400.0, ... }

# Points method: Splits time series into Single objects
data.points.first.house_power  # => 3750.0
```

> 💡 **More details:** Validation, error handling, and type conversion can be found in [sensor-reference.md](sensor-reference.md#data-container-details)

### 5. Formatting

#### Value Formatter

`Sensor::ValueFormatter` formats values based on units:

```ruby
# Watt/Kilowatt automatic
formatter = Sensor::ValueFormatter.new(2500, unit: :watt, context: :rate)
formatter.to_h
# => { value: "2.5", integer: "2", decimal: ".5", unit: "kW" }

# Euro (dynamic precision)
formatter = Sensor::ValueFormatter.new(1234.56, unit: :euro)
formatter.to_h
# => { value: "1,235", unit: "€" }  # >= 10 EUR without decimals
```

**Supported units:**
- `:watt` - Automatic W/kW/MW (+ Wh/kWh/MWh with context: :total)
- `:celsius` - Temperature in °C
- `:percent` - Percent with %
- `:unitless` - Unitless numbers (e.g., COP)
- `:boolean` - Yes/No
- `:string` - Pure text values
- `:gram` - CO2 in g/kg/t
- `:euro` - Currency
- `:euro_per_kwh` - Electricity price

#### View Component

`SensorValue::Component` combines sensor definition with formatter:

```ruby
# Basic usage
<%= render SensorValue::Component.new(data, :inverter_power) %>
# => <span class="sensor-value sensor-inverter-power">
#      <strong>2</strong><small>.5</small> <small>kW</small>
#    </span>

# With sign option (shows +/- and colors red/green)
<%= render SensorValue::Component.new(data, :grid_power, sign: :value_based) %>

# Direct value (without data object)
<%= render SensorValue::Component.new(2500, :inverter_power) %>
```

### 6. Chart Integration

Sensors define charts via `chart` block:

```ruby
class Sensor::Definitions::InverterPower < Sensor::Definitions::Base
  chart { |timeframe, variant: nil| Sensor::Chart::InverterPower.new(timeframe:, variant:) }
end

# Usage in controller
sensor = Sensor::Registry[:inverter_power]
chart = sensor.chart(timeframe, variant: :stacked)
render json: chart.call
```

**Chart classes** in `app/lib/sensor/chart/`:
- `InverterPower` - Inverter production
- `Autarky` - Autarky rate
- `BatteryPower` - Battery power
- `HousePower` - House consumption
- `GridPower` - Grid (import/export)
- ... (15+ charts)

#### Chart Permissions

Charts can implement access control via `permitted?`:

```ruby
class Sensor::Chart::Savings < Sensor::Chart::Base
  def permitted?
    ApplicationPolicy.finance_charts?
  end
end
```

The `ChartLoader` component checks `permitted?` and displays a sponsor hint if `false`. Finance charts (`Savings`, `GridRevenue`, `GridCosts`, `TotalCosts`) use this for sponsor-only access.

### 7. Configuration

`Sensor::Config` manages central configuration:

```ruby
# ENV variables (INFLUX_SENSOR_*)
Sensor::Config.setup(ENV)

# Check sensor configuration
Sensor::Config.exists?(:inverter_power)  # => true/false
Sensor::Config.configured?(:inverter_power)  # => true (ENV set)

# InfluxDB mapping
Sensor::Config.measurement(:inverter_power)  # => "SENEC"
Sensor::Config.field(:inverter_power)        # => "inverter_power"

# Filtered lists
Sensor::Config.chart_sensors      # => [all chart-capable sensors]
Sensor::Config.top10_sensors      # => [all Top10-capable sensors]
Sensor::Config.nameable_sensors   # => [all user-nameable sensors]

# Feature checks
Sensor::Config.multi_inverter?    # => true/false
Sensor::Config.single_consumer?   # => true/false
```

## Further Documentation

- **[Sensor Reference](sensor-reference.md)** - DSL reference, unit types, patterns, testing, troubleshooting
- **[SQL Queries](sensor-sql-queries.md)** - Detailed SQL query examples with generated SQL
- **Code reference**:
  - `app/lib/sensor/definitions/dsl.rb` - DSL implementation
  - `app/lib/sensor/registry.rb` - Registry implementation
  - `spec/lib/sensor/` - Comprehensive tests with examples
