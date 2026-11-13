# Current State

How prices and costs work in the code. This is the only file in this folder that names classes and methods. The other files point here.

Reviewed 2026-11-13 against `develop`. Any step that changes what is described here updates this file in the same commit.

## The `prices` table

A row is a name (`electricity` or `feed_in`), a start date, an amount per kWh and, for electricity only, an optional `amount_per_month` (the base fee). It is unique per name and start date and is in force until the next row of the same name. The kWh column is still called `value` for rollback compatibility; new code uses the alias `amount_per_kwh`.

The start is a date, so a day has exactly one price. Everything below rests on that.

Two lookups exist: `Price.at(name:, date:)` (one query per call) and `Price::Schedule`, which loads all rows once and answers `#at(name, date)` from memory.

## No energy cost is stored

No finance sensor has a stored aggregation, so nothing money-related is in `summary_values`. There are two calculation paths.

**SQL**, for days, months, years and rankings. `Sql::CteBuilder#build_price_cte` builds a `price_ranges` CTE and joins it onto the daily rows as `pb` (electricity) and `pf` (feed-in). The daily CTE carries `pb_money_per_kwh`, `pf_money_per_kwh` and the daily base fee (`FinanceBase::BASE_FEE_COLUMN`). A sensor's `#sql_calculation` references those columns and the per-field aggregates named `<field>_<aggregation>`, e.g. `grid_import_power_sum`. `Sql::QueryBuilder` and `Query::Ranking` collect `#required_prices` from the definitions and pass them to the CTE builder.

The daily CTE reads only the fields the query asks for. A day has a row, and with it a price and a base fee, when one of those fields has a value on that day. So whether a day carries the fee depends on the query. Most SQL expressions coalesce a missing energy to zero, so such a day costs 0 where the Ruby calculation returns nil.

**InfluxDB**, for hourly totals and chart series. `Influx::FinanceCalculation` (included by `Influx::Total` and `Query::Series`) resolves one price per type for the whole query via `Price.at(name:, date: timeframe.date)` and calls `#calculate_with_prices` on the definition, then `#with_base_fee`. For an hourly timeframe `timeframe.date` is today, so a price change inside the window is ignored.

## The base fee

`BaseFee` spreads the monthly amount over the days of its month (one day = monthly amount / days in month). The fee is never split between consumers. A sensor carries all of it or nothing (`FinanceBase#carries_base_fee?`): `grid_base_fee`, `house_costs_grid` and `traditional_costs` carry it. `grid_costs` is the sum of `grid_energy_costs` and `grid_base_fee`. A missing reading cancels the energy cost but not the fee.

## Two kinds of finance sensors

- **Priced sensors** implement `#calculate_with_prices` and a `#sql_calculation` with the same arithmetic. These are the 14 definitions in the table of [01](01-stored-costs.md#what-gets-stored); the four consumer `*_costs_grid` share `ConsumerGridCosts`. They are what becomes stored.
- **Composed sensors** add or subtract other finance sensors in a `calculate` block: `grid_costs`, `total_costs`, `solar_price`, `savings`, `grid_balance`, `house_without_custom_costs` and the consumer `*_costs`. Only `grid_costs` and `total_costs` are `FinanceBase` sensors; the rest derive from `Base`.

A composed sensor is calculated in two places:

- `Query::Total` (totals, grouped series, heatmap, amortization) fetches the parts by SQL and runs the **`calculate` block** per period. Most blocks return nil when any part is nil; only `grid_costs` and `grid_balance` tolerate a missing part.
- `Query::Ranking` runs **SQL**. `grid_costs`, `total_costs`, `solar_price` and `savings` have an own `#sql_calculation` that splices the SQL of their parts, and declare `#required_prices` for it. The others have none and are not ranked.

`docs/sensor-reference.md` derives `TotalCosts` from `Base` in one example and from `FinanceBase` in another. The second is right.

## Details that matter for the work

- **`Sensor::Config#exists?`** keeps a priced sensor alive only through `#sql_calculation` (it has no env variable and no `calculate` block). Remove the method and the sensor disappears from the registry, the menu and every query.
- **`SummaryBuilder#call`** collects raw and calculated values, then runs `#clean_invalid_sensor_values` (including `#nullify_sums_without_corresponding_max`) and `#apply_value_corrections` (`SummaryCorrector` rescales every `*_grid` share and caps custom consumers). Both change the energies a cost is made of. A finance sensor passes neither collection filter today.
- **`Sensor::SummaryInvalidator`** compares a stored configuration at boot and resets all summaries when it changed in a relevant way. A sensor added with history is such a change, so a rebuilt day never misses a consumer that had data.
- **`#corresponding_base_sensor`** maps a `_grid` share to its consumer (`heatpump_power_grid` → `heatpump_power`).
- **`Base#storable_fields`** resolves a sensor to the stored fields it comes down to. `Query::Ranking` uses it; `Sql::QueryBuilder` and `Sql::Total` read `dependencies(context: :sql)` instead.
- **`Influx::DailyBatch`** unions per-day pipelines into one Flux program (30-day rebuild 2265 → 535 ms against a remote InfluxDB). Letting InfluxDB cut the days itself (`aggregateWindow(fn: integral)`, `location`) was 4–11× slower. It sends two programs: per-day integrals for sum sensors, and per-day 5-minute means reduced to min/max/avg for sensors that declare those. The `_grid` shares and `custom_power_XX` declare a sum only.
- **Today's summary** goes stale after five minutes and is rebuilt alone, without the batch.
- **`MeasuredRange#installation_date`** clamps to `SummaryValue.minimum(:date)` over all fields.

## Other readers of the price

- **`ChargingSession`** stores `cost` and `cost_grid` per wallbox session from the prices of its day (`ChargingSession::Cost`), rounded to cents. `Price` reprices the sessions of the affected days after a save or destroy (`ChargingSession.reprice`, range before and after the change). It reads the stored session energy, not InfluxDB. This is the pattern for [01](01-stored-costs.md#recalculation-after-a-price-change).
- **`Car::Ledger::WithoutPv`** prices the wallbox energy of a day at that day's electricity price.
- **`Heatpump::Comparison`** does the same with the heat pump energy for its "without PV" column, and reads `heatpump_costs_grid` and `heatpump_costs_pv` via SQL.
- **Caches:** `AmortizationCalculator`, `Car::Savings` and `Heatpump::Savings` cache under a key that contains the price table version.
- **`McpServer::Tools::Prices`** (`get_prices`) reports one amount and base fee per entry.

## Outside this repository

`solectrus/tibber-collector` writes quarter-hourly gross spot prices to InfluxDB, stamped at the start of each interval, for today and tomorrow. It never backfills.
