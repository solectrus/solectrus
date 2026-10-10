# Current State

How prices and costs work in the code. Everything else in this folder builds on these facts. Most of the traps described there come from details listed here.

Reviewed 2026-09-14 against `develop`.

> **This file describes merged code only.** It starts as a description of `develop`, before any step of the [roadmap](roadmap.md). From there it follows the [working branch](roadmap.md#where-the-work-happens), so that every step is written against a true map. A step that changes something described here updates it in the same commit. The first change arrives with A1, which reaches the branch as a merge from `develop` rather than as a step.
>
> It is also the only file here that names classes and methods on purpose. It is the map the other files point at, so they can stay on the concept.

## The `prices` table

A row is a name (`electricity` or `feed_in`), a start date and an amount per kWh, unique per name and start date. It is a complete tariff, in force from its start date until the next row for the same name. The lookup takes the newest row on or before a date.

The start is a date, so a price change can only happen on a day boundary. A day therefore has exactly one price. That is the assumption the whole current calculation rests on, and it is what time-of-use and dynamic pricing break.

## No money is stored

Every finance sensor is declared `aggregations stored: false, computed: [:sum]`. Nothing money-related is in `summary_values`. A cost exists only for as long as it takes to render a page.

There are two calculation paths.

**SQL**, for days, months, years and rankings. `Sql::CteBuilder#build_price_cte` builds a `price_ranges` CTE, using `LEAD(starts_at)` for the validity window. It joins that CTE onto the daily rows twice: as `pb` for electricity and `pf` for feed-in. The daily CTE then carries `pb_money_per_kwh` and `pf_money_per_kwh` as plain columns, and the `#sql_calculation` of a sensor references those names. `Sql::QueryBuilder` and `Query::Ranking` each collect `required_prices` from the sensor definitions and pass them to the CTE builder.

The same CTE turns `summary_values` from rows into columns. `#build_sensor_filter_columns` writes one aggregate per required field and aggregation, named `<field>_<aggregation>`. So `grid_import_power_sum` is the column a `#sql_calculation` reads. That naming is what a stored finance sensor points its own `#sql_calculation` at.

**InfluxDB**, for hourly totals and chart series. `Sensor::Query::Helpers::Influx::FinanceCalculation` resolves one price per type for the whole query, via `Price.at(name:, date: timeframe.date)`. Then it calls `#calculate_with_prices` on the definition. The module is included by `Influx::Total` and by `Query::Series`, so the chart series does no finance math of its own.

## Which sensors are finance sensors

`Definitions::FinanceBase` is not the set of sensors that multiply energy by a price. Reading it as one misleads in both directions.

Most of its members do multiply. `total_costs` does not. It is a `FinanceBase` sensor with a `calculate` block, summing `grid_costs` and `opportunity_costs`. `Influx::FinanceCalculation` says so in its own comment and routes it to the generic Ruby calculation. The class is therefore what the InfluxDB path filters on, not what the sensor does.

Now the other direction. `savings`, `solar_price`, `grid_balance`, `house_without_custom_costs` and the four `*_costs` composites are plain `Definitions::Base` sensors with a `calculate` block. Two of them still declare prices. `savings` and `solar_price` declare `#required_prices` and `#sql_calculation` even though they never touch a price. Their SQL splices the SQL of `traditional_costs`, `grid_costs` and `grid_revenue`, so they inherit the `pb_` and `pf_` references of those sensors. They must declare the same price types, or the CTE does not build the columns. `grid_balance` and `house_without_custom_costs` declare neither, because they have no SQL path at all.

So three questions have three different answers, and a migration has to ask the right one:

- Is the sensor a `FinanceBase`? That is what the InfluxDB path collects prices from.
- Does it declare `#required_prices`? That is what the SQL CTE builds columns for.
- Does it price a quantity of its own? That is what becomes a stored field.

`docs/sensor-reference.md` describes the same subject and contradicts itself about it. Its "Finance Sensor as Dependency" example derives `TotalCosts` from `Definitions::Base`. Its permissions example, thirty lines later, derives the same class from `FinanceBase`. The second one is right. Read that file as an introduction to the DSL, not as a statement about which sensor is which.

## The details that break things

Each of these is load-bearing and easy to miss.

**`Sensor::Config#exists?` keeps finance sensors alive through `#sql_calculation`.** It treats a sensor as existing for one of two reasons: an `INFLUX_SENSOR_*` variable maps it, or it answers `calculated?` or `sql_calculated?` and all of its static dependencies exist. A finance sensor has no environment variable and no `calculate` block. So `#sql_calculation` is the only reason it is in `Sensor::Config.sensors`. Delete the method and the sensor disappears from the registry, the menu, the summary and every query.

**`SummaryBuilder` has no place for a finance sensor.** `sensors_for_aggregation(:sum)` keeps only sensors with `unit == :watt` that are `Sensor::Config.configured?`. `#calculated_sensors_for_aggregation` keeps only sensors that answer `calculated?`. A finance sensor passes neither test, so storing one needs a collection step of its own.

**`SummaryBuilder` rewrites its own numbers after collecting them.** `#call` collects, then runs `#clean_invalid_sensor_values`, then `#apply_value_corrections`. Two of those stages change the values a cost would be made of:

- `#nullify_sums_without_corresponding_max` turns an integral of `0` into `nil` when the sensor reported nothing all day.
- `#apply_value_corrections` runs `SummaryCorrector`. That class scales every `*_grid` share until the shares add up to `grid_import_power + battery_discharging_power_grid`, and it caps the custom consumers against the house. On a day with a meter fault these corrections are large, not cosmetic.

Today this is harmless, because costs are computed later, from the values that were already stored. Any change that computes a cost earlier has to deal with it.

**A day is judged stale in two places, not one.** `Summary.missing_or_stale_days` is a single statement over `summaries` and answers it for a whole range. `Sensor::Summarizer#pending_summaries` then asks each day again in Ruby, through `Summary#stale?`. It drops the days that answer no before any InfluxDB query runs. A rule that reaches only the statement has no effect.

**A power-splitter sensor knows what it is a share of.** `#corresponding_base_sensor` maps `heatpump_power_grid` to `heatpump_power` and so on, and `SummaryBuilder#fix_grid_sensors_against_base_sensors` already uses it. It is the path from a cost sensor back to the consumer a user configures.

**`Influx::DailyBatch` batches days into one Flux program, and the obvious alternative is slower.** `Sensor::Summarizer` slices the dates into chunks and hands each chunk to `DailyBatch`, which unions one stream per day into a single query. Its header comment records the measurement: a 30-day rebuild went from 2265 ms to 535 ms. It also records that letting InfluxDB cut the range itself was 4 to 11 times slower. Both `aggregateWindow(fn: integral)` and the `location` option needed for local midnights defeat the pushdown. Any calculation that needs its own query per day loses the batch, and the natural fix is exactly the function that comment warns about.

It sends **two** programs, not one, and they carry different sensors. `sum_sensor_names` goes into `#sum_flux` as a per-day integral. `aggregation_sensor_names` goes into `#aggregation_flux`, which builds a per-day stream of 5-minute means and unions three reductions of it. A sensor is only in the second list if it declares `min`, `max` or `avg`. The power-splitter sensors declare a sum alone, so they appear in the first program only.

**`Base#storable_fields` answers "which `summary_values` fields does this sensor come down to".** A stored sensor resolves to itself, a computed one to the stored fields of its SQL dependencies. `Query::Ranking` uses it today. It is what lets a converted and an unconverted finance sensor sit in the same query.

## Things that are already done

On `develop`:

- `AmortizationCalculator.cache_key` already contains the version of the price table, so a price edit is visible immediately.
- `Sensor::Units` already has a `:money_per_kwh` unit.
- The finance calculation for short timeframes lives in one shared module. It is therefore implemented once for both the hourly totals and the charts.

Outside this repository:

- `solectrus/tibber-collector` already writes spot prices to InfluxDB, at quarter-hourly resolution. No new collector is needed for dynamic pricing.
