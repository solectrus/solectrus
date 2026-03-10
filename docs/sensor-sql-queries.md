# Sensor::Query::Total - SQL Queries for Daily+ Timeframes

Detailed SQL query examples for the SQL branch of the Sensor System.

> 📖 **See also:** [Sensor Overview](sensor-overview.md) for core concepts and [Sensor Reference](sensor-reference.md) for DSL reference and technical details

## Overview

`Sensor::Query::Total` is a dispatcher. For hourly timeframes (`P1H` to `P99H`) it uses `Sensor::Query::Helpers::Influx::Total`; for non-hourly timeframes it delegates to `Sensor::Query::Helpers::Sql::Total`.

This document covers only the SQL path for daily and longer timeframes. In that mode, queries run against `summary_values`, optionally joined with the `prices` table. The DSL supports both simple single values and grouped time series with meta-aggregations and automatic finance calculations.

The SQL snippets below are representative. The current builder emits compact SQL, and price lookups are attached with `LEFT JOIN`s so sensor values can still be returned when a price row is missing.

## Core Functionality

### 1. Query Generation

- **Dynamic SQL creation**: Based on sensor definitions and dependencies
- **Meta-aggregations**: Combines base and meta-aggregations (e.g., `AVG` of `SUM`)
- **Dependency resolution**: Automatic addition of required sensor fields
- **Cost calculations**: Optional `LEFT JOIN` on the `prices` table for electricity costs and feed-in revenue
- **Post-processing**: Ruby-side calculation still runs after the SQL result is mapped, so calculated sensors can be composed from loaded dependencies

### 2. Data Structures

- **Input**: DSL with block (see API specification)
- **Output**: `Sensor::Data::Single` for single values, `Sensor::Data::Series` for time series
- **Timeframe**: Always required (passed as first parameter to constructor)
- **Grouping**: Optional for time series via `q.group_by` (`:day`, `:week`, `:month`, or `:year`). Since SummaryValues always contain daily values, grouping by days is technically redundant but implemented this way for simplicity and consistency.

### 3. Validation and Integration

- **Registry integration**: Uses `Sensor::Registry` for sensor definitions. Unknown sensor names throw an exception.
- **Config validation**: Checks for actually configured sensors; only these are included in queries.
- **Dependency resolution**: Uses `Sensor::DependencyResolver` for transitive dependencies
- **Automatic optimization**: Detects required aggregations and fields

### 4. Constraints

- **Sensor-agnostic**: The SQL builder is agnostic regarding concrete sensors. All required information is obtained from the registry.
- **Stored base data**: `summary_values` only contains per-day stored aggregations, never arbitrary calculated values.
- **Calculated sensors**: Non-stored calculated sensors are either resolved after the SQL query in Ruby or, if they provide `sql_calculation`, exposed through SQL expressions.
- **Finance and other SQL-calculated sensors**: `FinanceBase` sensors and a few regular sensors such as `heatpump_cop`, `co2_reduction`, `solar_price`, and `savings` can participate in the SQL path via `sql_calculation`.

## API Specification

### Constructor (DSL with Block)

```ruby
# Signature
Sensor::Query::Total.new(timeframe) do |q|
  q.sum :sensor_name                    # Meta-aggregation: sum, Base-aggregation: sum (default)
  q.avg :sensor_name, :min              # Meta-aggregation: avg, Base-aggregation: min
  q.group_by :month                     # Optional: Grouping for time series
end

# DSL methods for meta-aggregations:
# - q.sum(sensor_name, base_aggregation = :sum)
# - q.avg(sensor_name, base_aggregation = :avg)
# - q.min(sensor_name, base_aggregation = :min)
# - q.max(sensor_name, base_aggregation = :max)
#
# - q.group_by(value)   # Optional: :day/:month/:week/:year for time series
```

**Examples:**

```ruby
# Average of daily sums
Sensor::Query::Total.new(Timeframe.day) do |q|
  q.avg :house_power, :sum
end

# Minimum of daily minima
Sensor::Query::Total.new(Timeframe.month) do |q|
  q.min :case_temp, :min
end

# Multiple sensors with different aggregations
Sensor::Query::Total.new(Timeframe.new('2025-01')) do |q|
  q.sum :house_power                   # sum of sum (default)
  q.avg :case_temp, :min               # avg of min
end
```

**Supported aggregations:**

- **Requested aggregation methods**: `q.sum`, `q.avg`, `q.min`, `q.max` are validated against `allowed_aggregations`
- **Base aggregations**: Usually `:sum`, `:avg`, `:min`, `:max`, depending on what is available in `summary_values` or via SQL calculation

For the DSL, `allowed_aggregations` is the deciding capability list. This means a sensor can have broader conceptual SQL meta-aggregations than the public query API exposes.

### Return Types

When calling `call`, either `Sensor::Data::Single` or `Sensor::Data::Series` is returned.

## SQL Query Examples

The following examples all have the same structure and use a CTE (Common Table Expression) named "daily" - while not always necessary, this makes it easier for the SQL builder.

### 1. Simple Single Value Query

**Use case:** "Average daily house consumption in 2025"

```ruby
Sensor::Query::Total.new(Timeframe.new('2025')) do |q|
  q.avg :house_power, :sum
end.call
```

No calculated sensors, no costs. Very simple, this query is generated:

```sql
WITH daily AS (
  SELECT
    sv.date,
    SUM(sv.value) FILTER (WHERE sv.aggregation = 'sum' AND sv.field = 'house_power') AS house_power_sum
  FROM summary_values sv

  WHERE sv.date BETWEEN DATE '2025-01-01' AND DATE '2025-12-31'
    AND sv.aggregation IN ('sum')
    AND sv.field IN ('house_power')
  GROUP BY sv.date
)

SELECT AVG(house_power_sum) AS house_power_avg_sum
FROM daily
```

**Return:**

```ruby
data = Sensor::Data::Single.new(
  {
    [:house_power, :avg, :sum] => 1234.0
  },
  timeframe: Timeframe.new('2025')
)

# Access the value:
data.house_power(:avg, :sum)  # => 1234.0
```

### 2. Multi-Sensor Single Value Query

**Use case:** "Average daily house consumption and minimum case temperature in 2025"

```ruby
Sensor::Query::Total.new(Timeframe.new('2025')) do |q|
  q.avg :house_power, :sum
  q.min :case_temp, :min
end.call
```

This generates this query:

```sql
WITH daily AS (
  SELECT
    sv.date,
    SUM(sv.value) FILTER (WHERE sv.aggregation = 'sum' AND sv.field = 'house_power') AS house_power_sum,
    MIN(sv.value) FILTER (WHERE sv.aggregation = 'min' AND sv.field = 'case_temp')   AS case_temp_min
  FROM summary_values sv

  WHERE sv.date BETWEEN DATE '2025-01-01' AND DATE '2025-12-31'
    AND sv.aggregation IN ('sum','min')
    AND sv.field IN ('house_power','case_temp')

  GROUP BY sv.date
)

SELECT
  AVG(house_power_sum) AS house_power_avg_sum,
  MIN(case_temp_min)   AS case_temp_min_min
FROM daily
```

**Return:**

```ruby
data = Sensor::Data::Single.new(
  {
    [:house_power, :avg, :sum] => 1234.0,
    [:case_temp, :min, :min] => 23.4
  },
  timeframe: Timeframe.new('2025')
)

# Access the values:
data.house_power(:avg, :sum)  # => 1234.0
data.case_temp(:min, :min)    # => 23.4
```

### 3. Time Series Query (Grouped by Days)

**Use case:** "House consumption for each day in January 2025"

```ruby
Sensor::Query::Total.new(Timeframe.new('2025-01')) do |q|
  q.sum :house_power
  q.group_by :day
end.call
```

```sql
WITH daily AS (
  SELECT
    sv.date,
    SUM(sv.value) FILTER (WHERE sv.aggregation = 'sum' AND sv.field = 'house_power') AS house_power_sum
  FROM summary_values sv

  WHERE sv.date BETWEEN DATE '2025-01-01' AND DATE '2025-01-31'
    AND sv.aggregation IN ('sum')
    AND sv.field IN ('house_power')

  GROUP BY sv.date
)

SELECT
  date,
  SUM(house_power_sum) AS house_power_sum_sum

FROM daily

GROUP BY date
ORDER BY date
```

(Grouping is technically not necessary here. This is harmless for performance but enables a structurally identical query)

**Return:**

```ruby
data = Sensor::Data::Series.new(
  {
    [:house_power, :sum, :sum] => {
      Date.new(2025, 1, 1) => 1200.0,
      Date.new(2025, 1, 2) => 1150.0,
      Date.new(2025, 1, 3) => 1300.0,
      # ... for each day in January
    }
  },
  timeframe: Timeframe.new('2025-01')
)

# Access the time series:
data.house_power(:sum, :sum)
# => { Date(2025,1,1) => 1200.0, Date(2025,1,2) => 1150.0, ... }
```

### 4. Time Series Query with Grouping (Monthly)

**Use case:** "Average daily house consumption in 2025, grouped by month"

```ruby
Sensor::Query::Total.new(Timeframe.new('2025')) do |q|
  q.avg :house_power, :sum
  q.group_by :month
end.call
```

**Generated SQL:**

```sql
WITH daily AS (
  SELECT
    sv.date,
    SUM(sv.value) FILTER (WHERE sv.aggregation = 'sum' AND sv.field = 'house_power') AS house_power_sum
  FROM summary_values sv

  WHERE sv.date BETWEEN DATE '2025-01-01' AND DATE '2025-12-31'
    AND sv.aggregation IN ('sum')
    AND sv.field IN ('house_power')

  GROUP BY sv.date
)

SELECT
  date_trunc('month', date)::date AS month,
  AVG(house_power_sum)            AS house_power_avg_sum
FROM daily

GROUP BY 1
ORDER BY 1
```

**Return:**

```ruby
data = Sensor::Data::Series.new(
  {
    [:house_power, :avg, :sum] => {
      Date.new(2025, 1, 1) => 1234.5,  # January average
      Date.new(2025, 2, 1) => 1198.2,  # February average
      Date.new(2025, 3, 1) => 1156.8,  # March average
      # ... for each month in the year
    }
  },
  timeframe: Timeframe.new('2025')
)

# Access the time series:
data.house_power(:avg, :sum)
# => { Date(2025,1,1) => 1234.5, Date(2025,2,1) => 1198.2, ... }
```

### 5. Complex Multi-Sensor Query

**Use case:** "2025 annual overview: Total house consumption, total heat pump, total wallbox, total grid export, average min/max temperature"

```ruby
Sensor::Query::Total.new(Timeframe.new('2025')) do |q|
  q.sum :house_power
  q.sum :heatpump_power
  q.sum :wallbox_power
  q.sum :grid_export_power
  q.avg :case_temp, :min
  q.avg :case_temp, :max
end.call
```

**Generated SQL:**

```sql
WITH daily AS (
  SELECT
    sv.date,
    SUM(sv.value) FILTER (WHERE sv.aggregation = 'sum' AND sv.field = 'house_power')        AS house_power_sum,
    SUM(sv.value) FILTER (WHERE sv.aggregation = 'sum' AND sv.field = 'heatpump_power')     AS heatpump_power_sum,
    SUM(sv.value) FILTER (WHERE sv.aggregation = 'sum' AND sv.field = 'wallbox_power')      AS wallbox_power_sum,
    SUM(sv.value) FILTER (WHERE sv.aggregation = 'sum' AND sv.field = 'grid_export_power')  AS grid_export_power_sum,
    MIN(sv.value) FILTER (WHERE sv.aggregation = 'min' AND sv.field = 'case_temp')          AS case_temp_min,
    MAX(sv.value) FILTER (WHERE sv.aggregation = 'max' AND sv.field = 'case_temp')          AS case_temp_max
  FROM summary_values sv
  WHERE sv.date BETWEEN DATE '2025-01-01' AND DATE '2025-12-31'
    AND sv.aggregation IN ('sum','min','max')
    AND sv.field IN ('house_power','heatpump_power','wallbox_power','grid_export_power','case_temp')
  GROUP BY sv.date
)
SELECT
  SUM(house_power_sum)       AS house_power_sum_sum,
  SUM(heatpump_power_sum)    AS heatpump_power_sum_sum,
  SUM(wallbox_power_sum)     AS wallbox_power_sum_sum,
  SUM(grid_export_power_sum) AS grid_export_power_sum_sum,
  AVG(case_temp_min)         AS case_temp_avg_min,
  AVG(case_temp_max)         AS case_temp_avg_max
FROM daily
```

**Return:**

```ruby
data = Sensor::Data::Single.new(
  {
    [:house_power, :sum, :sum] => 45000.0,
    [:heatpump_power, :sum, :sum] => 12000.0,
    [:wallbox_power, :sum, :sum] => 8500.0,
    [:grid_export_power, :sum, :sum] => 15000.0,
    [:case_temp, :avg, :min] => 18.5,
    [:case_temp, :avg, :max] => 42.3
  },
  timeframe: Timeframe.new('2025')
)

# Access the values:
data.house_power(:sum, :sum)        # => 45000.0
data.heatpump_power(:sum, :sum)     # => 12000.0
data.case_temp(:avg, :min)          # => 18.5
data.case_temp(:avg, :max)          # => 42.3
```

### 6. Cost Calculation with Price JOIN

**Use case:** "2025 annual overview with costs: Temperature statistics plus traditional costs and grid revenue"

```ruby
Sensor::Query::Total.new(Timeframe.new('2025')) do |q|
  q.avg :case_temp, :min
  q.avg :case_temp, :max
  q.sum :traditional_costs
  q.sum :grid_revenue
end.call
```

**Note:** From `Sensor::Definitions::TraditionalCosts` and `Sensor::Definitions::GridRevenue` it follows that `traditional_costs` and `grid_revenue` are finance sensors that have no fields in SummaryValues. They are calculated via SQL calculations with power sensors (`house_power`, `heatpump_power`, `wallbox_power`, `grid_export_power`), which are automatically added to the query.

**Generated SQL:**

```sql
WITH price_ranges AS (
  SELECT
    name,
    starts_at,
    LEAD(starts_at, 1, 'infinity'::date) OVER (PARTITION BY name ORDER BY starts_at) AS next_start,
    value::numeric AS eur_per_kwh
  FROM prices
  WHERE name IN ('electricity','feed_in')
),

daily AS (
  SELECT
    sv.date,
    SUM(sv.value) FILTER (WHERE sv.aggregation = 'sum' AND sv.field = 'house_power')        AS house_power_sum,
    SUM(sv.value) FILTER (WHERE sv.aggregation = 'sum' AND sv.field = 'heatpump_power')     AS heatpump_power_sum,
    SUM(sv.value) FILTER (WHERE sv.aggregation = 'sum' AND sv.field = 'wallbox_power')      AS wallbox_power_sum,
    SUM(sv.value) FILTER (WHERE sv.aggregation = 'sum' AND sv.field = 'grid_export_power')  AS grid_export_power_sum,
    MIN(sv.value) FILTER (WHERE sv.aggregation = 'min' AND sv.field = 'case_temp')          AS case_temp_min,
    MAX(sv.value) FILTER (WHERE sv.aggregation = 'max' AND sv.field = 'case_temp')          AS case_temp_max,
    MAX(pb.eur_per_kwh) AS pb_eur_per_kwh,
    MAX(pf.eur_per_kwh) AS pf_eur_per_kwh
  FROM summary_values sv

  LEFT JOIN price_ranges pb
    ON pb.name = 'electricity'
   AND sv.date >= pb.starts_at
   AND sv.date < pb.next_start

  LEFT JOIN price_ranges pf
    ON pf.name = 'feed_in'
   AND sv.date >= pf.starts_at
   AND sv.date < pf.next_start

  WHERE sv.date BETWEEN DATE '2025-01-01' AND DATE '2025-12-31'
    AND sv.aggregation IN ('sum','min','max')
    AND sv.field IN ('house_power','heatpump_power','wallbox_power','grid_export_power','case_temp')
  GROUP BY sv.date
)

SELECT
  SUM(house_power_sum)     AS house_power_sum_sum,
  SUM(heatpump_power_sum)  AS heatpump_power_sum_sum,
  SUM(wallbox_power_sum)   AS wallbox_power_sum_sum,
  SUM(grid_export_power_sum) AS grid_export_power_sum_sum,
  AVG(case_temp_min)       AS case_temp_avg_min,
  AVG(case_temp_max)       AS case_temp_avg_max,
  SUM((COALESCE(house_power_sum,0) + COALESCE(heatpump_power_sum,0) + COALESCE(wallbox_power_sum,0)) * pb_eur_per_kwh / 1000.0) AS traditional_costs_sum_sum,
  SUM(grid_export_power_sum * pf_eur_per_kwh / 1000.0) AS grid_revenue_sum_sum
FROM daily
```

**Return:**

```ruby
data = Sensor::Data::Single.new(
  {
    [:case_temp, :avg, :min] => 18.5,
    [:case_temp, :avg, :max] => 42.3,
    [:traditional_costs, :sum, :sum] => 2345.67,  # Euro
    [:grid_revenue, :sum, :sum] => 1234.89        # Euro
  },
  timeframe: Timeframe.new('2025')
)

# Access the values:
data.case_temp(:avg, :min)          # => 18.5
data.case_temp(:avg, :max)          # => 42.3
data.traditional_costs(:sum, :sum)  # => 2345.67
data.grid_revenue(:sum, :sum)       # => 1234.89
```

### 7. Savings for a Month

```ruby
Sensor::Query::Total.new(Timeframe.new('2025-09')) do |q|
  q.sum :savings
end.call
```

**Note:** `savings` has both a `calculate` block and an `sql_calculation`. In the SQL path, `savings` itself is selected directly from SQL via `sql_calculation`. Some dependent sensors are still loaded so the mapped result can expose intermediate values such as `traditional_costs` and `solar_price`, and Ruby post-processing remains available for calculated sensors that do not already have their own SQL result.

**Return:**

```ruby
result = Sensor::Query::Total.new(Timeframe.new('2025-09')) do |q|
  q.sum :savings
end.call

result.traditional_costs  # => 2345.67
result.solar_price        # => 719.55
result.savings            # => 1626.12
```

### 8. Time Series with Cost Calculation (Monthly)

**Use case:** "Monthly overview 2025: Power sensors and costs"

```ruby
Sensor::Query::Total.new(Timeframe.new('2025')) do |q|
  q.sum :house_power
  q.sum :heatpump_power
  q.sum :wallbox_power
  q.sum :grid_export_power
  q.avg :case_temp, :min
  q.avg :case_temp, :max
  q.sum :traditional_costs
  q.sum :grid_revenue
  q.group_by :month
end.call
```

**Generated SQL:**

```sql
WITH price_ranges AS (
  SELECT
    name,
    starts_at,
    LEAD(starts_at, 1, 'infinity'::date) OVER (PARTITION BY name ORDER BY starts_at) AS next_start,
    value::numeric AS eur_per_kwh
  FROM prices
  WHERE name IN ('electricity','feed_in')
),

daily AS (
  SELECT
    sv.date,
    SUM(sv.value) FILTER (WHERE sv.aggregation = 'sum' AND sv.field = 'house_power')        AS house_power_sum,
    SUM(sv.value) FILTER (WHERE sv.aggregation = 'sum' AND sv.field = 'heatpump_power')     AS heatpump_power_sum,
    SUM(sv.value) FILTER (WHERE sv.aggregation = 'sum' AND sv.field = 'wallbox_power')      AS wallbox_power_sum,
    SUM(sv.value) FILTER (WHERE sv.aggregation = 'sum' AND sv.field = 'grid_export_power')  AS grid_export_power_sum,
    MIN(sv.value) FILTER (WHERE sv.aggregation = 'min' AND sv.field = 'case_temp')          AS case_temp_min,
    MAX(sv.value) FILTER (WHERE sv.aggregation = 'max' AND sv.field = 'case_temp')          AS case_temp_max,
    MAX(pb.eur_per_kwh)                                                                     AS pb_eur_per_kwh,
    MAX(pf.eur_per_kwh)                                                                     AS pf_eur_per_kwh
  FROM summary_values sv

  LEFT JOIN price_ranges pb
    ON pb.name = 'electricity'
   AND sv.date >= pb.starts_at
   AND sv.date < pb.next_start

  LEFT JOIN price_ranges pf
    ON pf.name = 'feed_in'
   AND sv.date >= pf.starts_at
   AND sv.date < pf.next_start

  WHERE sv.date BETWEEN DATE '2025-01-01' AND DATE '2025-12-31'
    AND sv.aggregation IN ('sum','min','max')
    AND sv.field IN ('house_power','heatpump_power','wallbox_power','grid_export_power','case_temp')
  GROUP BY sv.date
)

SELECT
  date_trunc('month', date)::date AS month,
  SUM(house_power_sum)       AS house_power_sum_sum,
  SUM(heatpump_power_sum)    AS heatpump_power_sum_sum,
  SUM(wallbox_power_sum)     AS wallbox_power_sum_sum,
  SUM(grid_export_power_sum) AS grid_export_power_sum_sum,
  AVG(case_temp_min)         AS case_temp_avg_min,
  AVG(case_temp_max)         AS case_temp_avg_max,
  SUM((COALESCE(house_power_sum,0) + COALESCE(heatpump_power_sum,0) + COALESCE(wallbox_power_sum,0)) * pb_eur_per_kwh / 1000.0) AS traditional_costs_sum_sum,
  SUM(grid_export_power_sum * pf_eur_per_kwh / 1000.0) AS grid_revenue_sum_sum

FROM daily

GROUP BY 1
ORDER BY 1
```

**Return:**

```ruby
data = Sensor::Data::Series.new(
  {
    [:house_power, :sum, :sum] => {
      Date.new(2025, 1, 1) => 3750.0,
      Date.new(2025, 2, 1) => 3400.0,
      Date.new(2025, 3, 1) => 3200.0
      # ... for each month in the year
    },
    [:heatpump_power, :sum, :sum] => {
      Date.new(2025, 1, 1) => 1200.0,
      Date.new(2025, 2, 1) => 1100.0,
      Date.new(2025, 3, 1) => 950.0
      # ... for each month in the year
    },
    [:wallbox_power, :sum, :sum] => {
      Date.new(2025, 1, 1) => 800.0,
      Date.new(2025, 2, 1) => 750.0,
      Date.new(2025, 3, 1) => 600.0
      # ... for each month in the year
    },
    [:grid_export_power, :sum, :sum] => {
      Date.new(2025, 1, 1) => 1250.0,
      Date.new(2025, 2, 1) => 1400.0,
      Date.new(2025, 3, 1) => 1800.0
      # ... for each month in the year
    },
    [:case_temp, :avg, :min] => {
      Date.new(2025, 1, 1) => 15.2,
      Date.new(2025, 2, 1) => 12.8,
      Date.new(2025, 3, 1) => 18.5
      # ... for each month in the year
    },
    [:case_temp, :avg, :max] => {
      Date.new(2025, 1, 1) => 38.9,
      Date.new(2025, 2, 1) => 42.1,
      Date.new(2025, 3, 1) => 45.3
      # ... for each month in the year
    },
    [:traditional_costs, :sum, :sum] => {
      Date.new(2025, 1, 1) => 195.45,
      Date.new(2025, 2, 1) => 178.23,
      Date.new(2025, 3, 1) => 156.89
      # ... for each month in the year
    },
    [:grid_revenue, :sum, :sum] => {
      Date.new(2025, 1, 1) => 102.75,
      Date.new(2025, 2, 1) => 115.60,
      Date.new(2025, 3, 1) => 148.90
      # ... for each month in the year
    }
  },
  timeframe: Timeframe.new('2025')
)

# Access the time series:
data.house_power(:sum, :sum)
# => { Date(2025,1,1) => 3750.0, Date(2025,2,1) => 3400.0, ... }

data.traditional_costs(:sum, :sum)
# => { Date(2025,1,1) => 195.45, Date(2025,2,1) => 178.23, ... }
```

## Implementation Details

### Architecture Principles

**The implementation is clearly organized into helper classes:**

- **Dispatcher entrypoint** (`Sensor::Query::Total`) - selects SQL or Influx backend
- **DslBuilder** (`app/lib/sensor/query/helpers/sql/dsl_builder.rb`) - DSL builder for block syntax with validation
- **QueryBuilder** (`app/lib/sensor/query/helpers/sql/query_builder.rb`) - Coordinates SQL query generation, analyzes sensor requirements
- **CteBuilder** (`app/lib/sensor/query/helpers/sql/cte_builder.rb`) - Builds CTEs (price_ranges, daily) with FILTER clauses
- **SelectBuilder** (`app/lib/sensor/query/helpers/sql/select_builder.rb`) - Builds final SELECT with grouping
- **ResultMapper** (`app/lib/sensor/query/helpers/sql/result_mapper.rb`) - Formats query results to `Sensor::Data::Single/Series`

### Important Implementation Notes

1. Sensor-agnostic architecture

There must be no hard-coded sensor names in the SQL classes. **This is extremely important!** All information must be obtained from Sensor::Registry and sensor definitions. This especially applies to price sensors like Sensor::Definitions::TraditionalCosts, which contain the `sql_calculation` method that must be used.

2. Calculated sensors can be applied after the SQL query

Pure Ruby calculated sensors are applied based on the mapped query result, so their dependencies must be present in the SQL query. Sensors with `sql_calculation` can additionally contribute SQL expressions directly.

3. Finance sensors have no DB fields in SummaryValues

Costs and revenues are determined via SQL calculations with power sensors and price `LEFT JOIN`s.

## Performance

Performance is important for the generated SQL query:

- **Selective fields**: Only actually needed fields are included in WHERE clause
- **Selective aggregations**: Only needed aggregations are filtered
- **Minimal JOINs**: Price `LEFT JOIN`s are only added when cost or revenue sensors are requested

## Further Documentation

- **[Sensor Overview](sensor-overview.md)** - Introduction to the Sensor System
- **[Sensor Reference](sensor-reference.md)** - DSL reference, finance sensors, testing, performance
- **Code reference**:
  - `app/lib/sensor/query/total.rb` - Main dispatcher (auto-selects Influx/SQL)
  - `app/lib/sensor/query/helpers/sql/total.rb` - SQL implementation
  - `app/lib/sensor/query/helpers/sql/` - SQL builder classes
  - `app/lib/sensor/definitions/finance_base.rb` - Finance sensors base
  - `spec/lib/sensor/query/` - Comprehensive tests
