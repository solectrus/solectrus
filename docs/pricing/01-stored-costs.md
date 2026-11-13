# Stored Costs

Calculate the money once per day in `SummaryBuilder` and store it in `summary_values`, instead of joining `prices` at query time. The tariffs do not change. This is plumbing, and the prerequisite for [03](03-sub-day-prices.md).

Steps A2 to A5 in the [roadmap](roadmap.md#block-a--postgresql-only). Issue #5340.

## Why

A daily energy sum cannot say how much of it fell into the expensive hours. So with time-of-use or dynamic prices the multiplication has to happen while sub-day data is reachable, which is in the summary step. Afterwards the SQL path gets simpler: a cost is a stored field summed like `house_power`, and the price join disappears.

## What gets stored

Every definition that prices a quantity of its own becomes `stored: [:sum]`. A field carries the name of its sensor.

| Sensor                     | Price       | Priced quantity                                        |
| -------------------------- | ----------- | ------------------------------------------------------ |
| `grid_energy_costs`        | electricity | `grid_import_power`                                    |
| `grid_base_fee`            | —           | the base fee of the day                                |
| `grid_revenue`             | feed_in     | `grid_export_power`                                    |
| `house_costs_grid`         | electricity | `house_power_grid`, plus the base fee                  |
| `house_costs_pv`           | feed_in     | `house_power − house_power_grid`                       |
| `heatpump_costs_grid/_pv`  | as house    | `heatpump_power(_grid)`                                |
| `wallbox_costs_grid/_pv`   | as house    | `wallbox_power(_grid)`                                 |
| `custom_XX_costs_grid/_pv` | as house    | `custom_power_XX(_grid)`, XX = 01–20                   |
| `battery_savings`          | both        | battery charge and discharge, and their `_grid` shares |
| `opportunity_costs`        | feed_in     | `inverter_power − grid_export_power`                   |
| `traditional_costs`        | electricity | the parts of `total_consumption`, plus the base fee    |

That is 52 enum values, 40 of them the custom pairs. Enum values cannot be removed from a user's database, but they can be corrected while the work is on the branch.

The composed sensors stay computed: `grid_costs`, `house_costs`, `heatpump_costs`, `wallbox_costs`, `custom_XX_costs`, `grid_balance`, `solar_price`, `savings`, `house_without_custom_costs` and `total_costs`.

About 21 rows per day for a typical setup, 38,000 over five years. No new index.

## Priced terms

A cost definition returns its terms: an energy, a price type, and (from A6) a consumer. `FinanceBase` multiplies each term by its resolved price, sums, and adds the base fee where the sensor carries it. Clamps such as `max(house − house_grid, 0)` live in the term method.

This replaces the 13 hand-written multiplications in `#calculate_with_prices` once, in A2, without changing a number. Then all callers use the same terms: the cost step, the recalculation, the InfluxDB path, the consumer tariffs in [02](02-consumer-tariffs.md), and the per-window pricing in [03](03-sub-day-prices.md).

## The cost step

A new collection step at the end of `SummaryBuilder#call`, **after** `#clean_invalid_sensor_values` and `#apply_value_corrections`. Invariant, defended by a spec:

> A stored cost is the price applied to the stored energy, never to the energy before correction.

- The step reads the corrected daily energies, resolves the prices of the day with `Price::Schedule`, and stores what the terms produce.
- Finance sensors stay out of the list sent to `Influx::DailyBatch`. The existing filters (configured watt sensors) already do that; do not relax them.
- No clamp and no range check. Costs and revenues can be negative with spot prices.
- Store the float. Round only when formatting.

## The SQL path

`#sql_calculation` stays and points at the sensor's own column, because `Sensor::Config#exists?` depends on it. Do not coalesce a stored column to zero.

### A day without energy is NULL

Today a day without an energy row costs 0. Afterwards it has no cost row. Sums stay the same; `min` and the top-10 ranking change, because a day the meter never reported did not cost nothing. This is the correct number and goes into the changelog.

`battery_savings`, `opportunity_costs` and `traditional_costs` currently return a number when a dependency is missing. They must return nil when no dependency has a value (A4).

### A composed sensor tolerates a missing part

`grid_costs`, `solar_price`, `savings`, `total_costs` and the consumer `*_costs` splice the SQL of their parts. Once the parts are stored columns, a missing part is NULL and makes the whole day NULL. A day without export would drop out of `savings`, and with it out of the amortization. This starts with the first stored sensor, because `solar_price` and `savings` splice `grid_revenue`.

So every composed sensor builds its SQL through one helper on `FinanceBase`: coalesce each part, NULL only when all parts are NULL. The Ruby side of `grid_costs` already follows that rule. A spec per composed sensor with one part missing.

## The base fee

`grid_base_fee` is stored like the rest, so the price join can go entirely. It follows today's rule: a fee row only on a day that has at least one measured value. That keeps the numbers unchanged, and `MeasuredRange` keeps seeing only measured days.

## Recalculation after a price change

From A3 on a price edit leaves wrong stored costs unless they are recalculated. The recalculation follows `ChargingSession.reprice`:

1. Range: the validity window of the record before and after the change, as a union. A deleted row or a moved start date affects its neighbors.
2. Load the stored energies of that range from `summary_values`.
3. Run the same cost step per day.
4. Delete the cost rows of the range, then insert the new ones. An upsert alone would leave the cost of a day whose tariff is gone.

No InfluxDB and no second formula. The one-time backfill when upgrading is the same code over the whole history.

### Where it runs

Inline, in the transaction that saves the price. Then a price and its costs are always consistent, and a failure shows as an error on the form.

_Stop point 1:_ measure the edit of the oldest price on five years of seeded summaries. If it is too slow for a form submit, move it into a job. A job must mark the affected summaries stale when it fails, so they rebuild from InfluxDB instead of staying silently wrong.

Two edits do not trigger it: a price written outside the model (console, SQL) and a summary run already in flight while the price is saved. Do not guard against either. The repair is the same recalculation over the range; name it where it lives.

### Sub-day modes rebuild instead

A cost under time-of-use or dynamic prices needs sub-day data, so the recalculation cannot redo it from stored daily energy. An edit that involves such a mode deletes the affected summaries and returns. The existing staleness mechanism rebuilds them in the background. Never rebuild inline. This arrives in C1.

### The amortization cache

`AmortizationCalculator` caches under a key that includes the price table version. After a sub-day edit the key changes immediately, but the summaries are rebuilt only over the next page views, so the cache stores a figure computed from a gap. _Stop point 3:_ either rebuild before returning, or do not cache while days are missing.

## What stays

The hourly totals and the chart series have no daily row to read. They keep calculating in Ruby through `Influx::FinanceCalculation`, which reads `#required_prices` and the priced terms. Not a single Flux query changes in block A.

## Correctness check

Write it as a spec before converting: seed days, record day, month, year and top-10 from the current code as expected values, then convert. The seed needs a price change inside the period, a day without energy data, and a day without export.

Expected differences: `min` and ranking where a day has no energy. Totals agree within float tolerance (the old path multiplies in `numeric`, the new one in `Float`); a cent or more is a bug.

The spec proves the arithmetic. Comparing the same figures on a real database before and after A3 is the acceptance.

## Rollback

Not supported. An older version ignores the cost rows but does not keep them true when it rebuilds a stale day. Say in the release notes: after a downgrade and a later upgrade, reset the summaries once.

## Traps

- Cost step before the corrections: stored cost and stored energy disagree.
- A composed sensor without the coalesce helper: whole days vanish from `savings` and the amortization.
- Deleting `#sql_calculation`: the sensor leaves the registry.
- Deleting `#required_prices` or the terms with the CTE: hourly views and charts break.
- Fee rows on days without measurements: `MeasuredRange` moves the installation date back.
