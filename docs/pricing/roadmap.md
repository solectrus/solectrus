# Roadmap

The order of the work. The feature files say what and why; this file says when.

One rule shapes the order: **everything that touches only PostgreSQL comes before anything that touches InfluxDB.** In fixed mode a daily cost is the stored daily energy times a number, so storing costs and consumer tariffs need no Flux query. Only sub-day prices do.

## Where the work happens

A1 went to `develop` on its own. Every step from A2 on stays on one working branch until the roadmap is finished, because new enum values in `summary_values` cannot be removed once a user has them, and B1 may still change the plan for C.

- Merge `develop` into the branch regularly. Expect `.changelog/unreleased.md` to conflict each time.
- Enum names stay correctable until a release ships them. Consolidate the migrations before the branch goes to `develop`.
- Every step leaves the application consistent and is reviewable on its own, even though none is released on its own.

## Status

Update this table in the commit that finishes a step.

| Step | What                   | Status |
| ---- | ---------------------- | ------ |
| A1   | Monthly base fee       | done   |
| A2   | Preparation            | todo   |
| A3   | Pilot: `grid_revenue`  | todo   |
| A4   | All other cost sensors | todo   |
| A5   | Retire the price join  | todo   |
| A6   | Consumer tariffs       | todo   |
| B1   | Windowed daily batch   | todo   |
| C1   | Time-of-use            | todo   |
| C2   | Dynamic prices         | todo   |

## Stop points

Four points need a decision the work cannot make itself. Do the work up to there, present the numbers or options, and wait.

1. **A3:** how long the recalculation after a price edit takes on five years of summaries. Inline or job? See [01](01-stored-costs.md#where-it-runs).
2. **B1:** the benchmark of the windowed batch. Decides whether block C goes ahead.
3. **C1:** the amortization cache while summaries are rebuilt after a time-of-use edit. See [01](01-stored-costs.md#the-amortization-cache).
4. **C2:** the `t` flag of the price sensors in the MCP tool matrix. See [03](03-sub-day-prices.md#mcp).

## Block A — PostgreSQL only

The hourly and chart views keep calculating money in Ruby throughout. See [01](01-stored-costs.md#what-stays).

### A1 — Monthly base fee (done)

On `develop`, issue #2560. See [current-state.md](current-state.md#the-base-fee).

### A2 — Preparation

No behavior change.

1. Every definition that prices something returns its **priced terms** (energy, price type, consumer), and `FinanceBase` does the multiplication. See [01](01-stored-costs.md#priced-terms).
2. The two places that collect the SQL dependencies of a finance sensor ask for `storable_fields` instead. Without this, A3 references a column the CTE never selected.

### A3 — Pilot: `grid_revenue`

1. Enum value, `stored: [:sum]`, `#sql_calculation` points at the own column.
2. The cost step in `SummaryBuilder`, after the value corrections. See [01](01-stored-costs.md#the-cost-step).
3. The coalesce helper for composed sensors, with `solar_price` and `savings` through it, because both build on `grid_revenue`. See [01](01-stored-costs.md#a-composed-sensor-tolerates-a-missing-part).
4. The recalculation after a price change, which also does the backfill. _Stop point 1._
5. Check the heatmap, which switches to the stored-column path.
6. The comparison spec: day, month, year and top-10 against the values from before.

Fix two comments that stop being true: the heatmap's example of the calculated path, and the reason given in `AmortizationCalculator.cache_key`.

### A4 — All other cost sensors

The rest of the table in [01](01-stored-costs.md#what-gets-stored) in one step. Includes:

- `battery_savings`, `opportunity_costs` and `traditional_costs` return nil on a day without energy. See [01](01-stored-costs.md#a-day-without-energy-is-null).
- `SummaryInvalidator` compares the dependency list of `traditional_costs`, so configuring a heat pump or wallbox later invalidates the frozen costs.

Each user-visible difference (a day without data is no longer a zero-cost day) gets its line in `.changelog/unreleased.md`.

### A5 — Retire the price join

The query builders stop reading `#required_prices`; the price CTE and its joins go. `#required_prices` stays where the InfluxDB path reads it and goes from `savings`, `solar_price` and `total_costs`.

Rewrite the "Finance Sensors" chapter of `docs/sensor-reference.md` and the three price-join examples in `docs/sensor-sql-queries.md`.

### A6 — Consumer tariffs

See [02](02-consumer-tariffs.md). Still no InfluxDB.

1. `consumer` on a price entry, unique index including it, and an `inherit` flag to end a consumer tariff.
2. `Price::Schedule` resolves consumer → default.
3. The cost step and the recalculation resolve the price per term.
4. `grid_energy_costs` = consumer shares at their rates plus the remainder at the default rate.
5. `traditional_costs` prices each part at its own rate.
6. `ChargingSession::Cost` and `Heatpump::Comparison` use the wallbox and heat pump tariff.
7. Settings UI, `get_prices` with the consumer, then `bin/llm-test`.

## Block B — InfluxDB

### B1 — Windowed daily batch

Extend `Influx::DailyBatch` with per-day windowed means that keep their buckets, only for the sensors a cost term is made of. See [03](03-sub-day-prices.md#query-cost).

Benchmark against the current programs on the local test InfluxDB, filled with 20 custom consumers (53 sensors). Measure the query, the Ruby parse, and a single day without the batch. Report the ratio to the current batch, not absolute times. _Stop point 2._ An hourly window (time-of-use) returns a quarter of the rows of a 15-minute one, so a bad 15-minute result does not necessarily block C1.

## Block C — Sub-day prices

See [03](03-sub-day-prices.md).

### C1 — Time-of-use

1. Mode and slots on a price entry, slots on the full hour, amount nullable in database and model.
2. Shape times amount in the cost step, hourly window.
3. `Influx::FinanceCalculation`: a price per chart point, and hourly totals split at slot boundaries.
4. Charging sessions and the heat pump comparison at the time-weighted mean price. See [03](03-sub-day-prices.md#charging-sessions-and-the-heat-pump-comparison).
5. Settings UI for slots; `get_prices` reports the slots; `bin/llm-test`.
6. A time-of-use edit deletes the affected summaries and lets them rebuild. _Stop point 3._

Spec: a time-of-use tariff with the same amount in every slot returns exactly what the fixed tariff returned.

### C2 — Dynamic prices

Spot prices and direct marketing (#4947) together, because the path does not care which tariff it reads.

1. `electricity_price` and `feed_in_price` sensors: `money_per_kwh`, average only, never stored, in no `depends_on`.
2. Document their mapping with `tibber-collector` as the example.
3. The quarter-hourly path in the cost step and in `Influx::FinanceCalculation`.
4. The marker for days without price data, taught to both staleness checks.
5. The form refuses `dynamic` without a configured price sensor and warns that history before the collector has no cost.
6. Price sensors in `list_sensors`. _Stop point 4._ Then `bin/llm-test`.

## Not on this roadmap: energy sharing

[04](04-energy-sharing.md) waits for a data source outside SOLECTRUS. It would slot in after C and use the tariff machinery of A6. Until then, do not make it impossible for `grid_energy_costs` and `grid_revenue` to subtract a community part.
