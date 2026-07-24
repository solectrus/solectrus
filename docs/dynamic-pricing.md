# Dynamic Pricing Concept

> **Status:** Concept only, not yet implemented. Written 2026-03, last reviewed 2026-07-24 against the code on `develop`. Currency support has been implemented in the meantime (see below); the finance calculation for short timeframes has moved into a shared query helper since the first draft.

## Related Issues / Discussions

- #5340 - Dynamic pricing (meta issue for this concept)
- #2150 - Dynamic tariffs (Tibber, aWATTar)
- #2560 - Monthly base fee
- #2797 - Currency configuration (e.g. CHF instead of EUR) — **done**, implemented via #5623
- #4832 - Time-of-use tariffs (§14a EnWG, module 3)
- #4850 - Consumer-specific tariffs
- #4947 - Dynamic feed-in tariffs (direct marketing)
- #5227 - Heat pump electricity tariffs
- #5334 - Renewable energy communities / energy sharing (multiple suppliers) — discussion

See also: #3198 (CO₂ emissions based on time-dependent grid intensity) — not part of this concept, but the dynamic path (consumption series × price series from InfluxDB) is exactly the calculation shape that a time-dependent CO₂ factor will need as well.

## Current State

Prices are stored in PostgreSQL (`prices` table) with a fixed value per kWh, valid from a start date. There is one electricity price and one feed-in price at any given time, applying equally to all consumers. Nothing money-related is persisted: every finance sensor is declared `aggregations stored: false, computed: [:sum]` and is calculated at query time.

There are two calculation paths today:

- **SQL** (days, months, years, rankings): `Sql::CteBuilder#build_price_cte` builds a `price_ranges` CTE (`LEAD(starts_at)` for the validity range, `value` aliased as `money_per_kwh`), which is joined as `pb` (electricity) and `pf` (feed_in). Both `Sql::QueryBuilder` and `Query::Ranking` collect `required_prices` from the sensor definitions and pass them into the CTE builder; the definitions reference the join aliases in `#sql_calculation`.
- **InfluxDB** (hourly totals and chart series): `Sensor::Query::Helpers::Influx::FinanceCalculation` resolves one price per type via `Price.at(name:, date: timeframe.date)` and calls `#calculate_with_prices` on the definition. It is included by `Helpers::Influx::Total` **and** by `Sensor::Query::Series` — the chart series no longer does its own finance math.

Not every money sensor is a `FinanceBase`: `savings`, `solar_price`, `grid_balance` and `house_without_custom_costs` are plain `Definitions::Base` sensors with a `calculate` block; only those that actually multiply power by a price derive from `FinanceBase`.

The currency is already configurable via the `CURRENCY` env var (ISO-4217, default `EUR`, see `Currency` module) — this part of the original concept has been implemented in the meantime.

## Goal

Support three pricing models, consumer-specific pricing, and monthly base fees:

| Mode            | Description                               | Example                          |
| --------------- | ----------------------------------------- | -------------------------------- |
| **Fixed**       | Single price per kWh                      | 0.30 per kWh from 2024-01-01     |
| **Time-of-Use** | Fixed prices per time slot within a day   | HT 0.30 (6-22h), NT 0.20 (22-6h) |
| **Dynamic**     | Spot market price, changes every 15min/1h | Tibber, aWATTar                  |

Additionally:

- Different consumers can have **different prices** (e.g. heat pump on a cheaper rate)
- A monthly **base fee** can be defined per price entry
- Feed-in prices also support all three modes (for direct marketing)
- ~~The **currency** is configurable (e.g. CHF instead of EUR)~~ — already implemented (#5623)

All of these can change over time independently. A realistic timeline might look like this:

```
2020-02-01  Fixed 0.28 EUR/kWh, feed-in 0.082 EUR/kWh, base fee 10 EUR/month
2021-06-01  Fixed 0.32 EUR/kWh (new contract), base fee 12 EUR/month
2023-01-01  Tibber (dynamic spot prices), base fee 8 EUR/month
2024-03-01  aWATTar (dynamic, different provider), base fee 9 EUR/month
2025-01-01  Time-of-Use HT 0.30 / NT 0.20 EUR/kWh (§14a module 3), base fee 12 EUR/month
            + Heat pump on separate meter: fixed 0.22 EUR/kWh, base fee 8 EUR/month
2025-07-01  Tibber (back to dynamic), base fee 8 EUR/month; heat pump stays on ToU
2026-01-01  Feed-in switches to dynamic (direct marketing), base fee 5 EUR/month
2026-06-01  Join energy community: community import 0.15 EUR/kWh, community export 0.12 EUR/kWh, base fee 2 EUR/month
```

---

## Data Model

### `prices` table (extended)

```
name:       enum (electricity / feed_in)                                     (existing, unchanged)
starts_at:  date, not null                                                   (existing)
mode:       enum (fixed / time_of_use / dynamic / inherit), default: fixed   (new)
value:      decimal(8,5), nullable                                           (existing, becomes nullable)
time_slots: jsonb, nullable                                                  (new, only for time_of_use)
base_fee:   decimal(8,2), nullable                                           (new, monthly base fee)
consumer:   string, not null, default: 'all'                                 (new)
note:       string, nullable                                                 (existing)
```

**Column details:**

- `name`: Unchanged. `electricity` for grid purchase prices, `feed_in` for feed-in tariffs.
- `mode`:
  - `fixed` - `value` contains the price per kWh (as before)
  - `time_of_use` - `value` is `nil`, time slots with prices are defined in `time_slots`
  - `dynamic` - `value` is `nil`, prices come from InfluxDB
  - `inherit` - only valid for a specific `consumer`: from this date on, that consumer falls back to the `'all'` price again. Without it, a consumer-specific tariff could never be ended — the lookup below always picks the newest consumer entry `<= date`, so a heat pump that returns to the household tariff would keep its old price forever.
- `time_slots`: JSON array for time-of-use mode, e.g. `[{"starts_at": "00:00", "value": 0.20}, {"starts_at": "06:00", "value": 0.30}, {"starts_at": "22:00", "value": 0.20}]`. Each slot runs from its `starts_at` until the next slot's `starts_at` (or `"24:00"` / end-of-day for the last entry). The `next_starts_at` is derived at runtime from the array order — it is not stored. Slot boundaries are **local wall-clock times**, so a DST day has 23 or 25 hours (see below).
- `base_fee`: Monthly fixed cost in the configured currency (meter fee, service charge, etc.). Applies from `starts_at` until the next entry **for the same `consumer`**. `nil` means "no base fee", not "unchanged" — a new price entry therefore has to repeat the fee, and the form should prefill it from the previous entry. Each `consumer` with a base fee represents a separate contract/meter. When displaying monthly costs, the fees of all consumers are summed (e.g. default tariff 12 + heat pump tariff 8 = 20/month total).
- `consumer`: When `'all'`, this price applies to all consumers without a specific entry. When set to a specific sensor name (e.g. `heatpump_power`, `wallbox_power`), this price applies only to that consumer. Stored as a **string** (not an enum) so new sensor types can be added without code changes. Validated against the list of configured power sensors at runtime (`Sensor::Config.configured?`).

**Unique index** changes from `(name, starts_at)` to `(name, starts_at, consumer)`:

```sql
CREATE UNIQUE INDEX index_prices_uniqueness
  ON prices (name, starts_at, consumer)
```

**Validation rules:**

- `fixed`: `value` required, `time_slots` must be nil
- `time_of_use`: `time_slots` required, `value` must be nil. First entry must start at `"00:00"`, entries must be in chronological order, and must cover the full 24 hours.
- `dynamic`: both `value` and `time_slots` must be nil
- `inherit`: both `value` and `time_slots` must be nil, `consumer` must not be `'all'`
- `base_fee`: optional for all modes, must be >= 0 when present

Two existing bits of the `Price` model have to follow along: the `uniqueness: { scope: :name }` validation becomes `scope: %i[name consumer]`, and `Price.seed!` has to write `consumer: 'all'`, `mode: :fixed` explicitly.

### InfluxDB (new, only for Dynamic mode)

```
Measurement: electricity_price   field: price_per_kwh
Measurement: feed_in_price       field: price_per_kwh
```

Written by an external collector (Tibber API, aWATTar API, etc.). Interval depends on provider (15min or 1h). The Tibber collector already exists and writes to InfluxDB.

For dynamic mode, the InfluxDB measurement is determined by `name`: `electricity` reads from `electricity_price`, `feed_in` reads from `feed_in_price`. This applies regardless of the `consumer` field - all consumers with dynamic electricity pricing share the same spot price series.

### Currency (already implemented)

The currency is a global setting (`CURRENCY` env var, ISO-4217 code, default `EUR`), implemented via #5623 (`Currency` module, `money_per_kwh` SQL aliases, `:money` unit in `Sensor::UnitFormatter`). It is purely a display concern:

- Display: All monetary values are formatted with the configured currency symbol
- Price input: Labels and placeholders show the configured currency
- Calculations: No change needed — all formulas work in the configured currency unit, since prices and costs are always in the same currency

All columns storing monetary values (`value` and, once added, `base_fee` and stored finance sensor values in `summary_values`) are plain decimals without currency reference. Nothing in this concept changes that.

### `summary_values` (extended)

Finance sensors change from computed to **stored** sensors. Their daily cost totals are written directly to `summary_values`.

**Stored finance sensors** (price × consumption, calculated by SummaryBuilder):

| Sensor                     | Price                   | Consumption sensor                                                                                                                                                              |
| -------------------------- | ----------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `grid_costs`               | electricity             | `grid_import_power`                                                                                                                                                             |
| `grid_revenue`             | feed_in                 | `grid_export_power`                                                                                                                                                             |
| `house_costs_grid`         | electricity             | `house_power_grid`                                                                                                                                                              |
| `house_costs_pv`           | feed_in                 | `house_power` - `house_power_grid`                                                                                                                                              |
| `heatpump_costs_grid`      | electricity             | `heatpump_power_grid`                                                                                                                                                           |
| `heatpump_costs_pv`        | feed_in                 | `heatpump_power` - `heatpump_power_grid`                                                                                                                                        |
| `wallbox_costs_grid`       | electricity             | `wallbox_power_grid`                                                                                                                                                            |
| `wallbox_costs_pv`         | feed_in                 | `wallbox_power` - `wallbox_power_grid`                                                                                                                                          |
| `custom_XX_costs_grid`     | electricity             | `custom_power_XX_grid` (per custom consumer, XX = 01–20)                                                                                                                        |
| `custom_XX_costs_pv`       | feed_in                 | `custom_power_XX` - `custom_power_XX_grid`                                                                                                                                      |
| `battery_charging_costs`   | electricity             | `battery_charging_power_grid`                                                                                                                                                   |
| `battery_savings`          | electricity + feed_in   | `battery_discharging_power`, `battery_charging_power`                                                                                                                           |
| `opportunity_costs`        | feed_in                 | `inverter_power` - `grid_export_power` (self-consumed solar)                                                                                                                    |
| `traditional_costs`        | electricity             | total consumption — the dependencies of `total_consumption` (`house_power` plus heat pump, wallbox and the custom consumers excluded from `house_power`), priced per dependency |
| `community_import_costs`   | electricity (community) | `community_import_power`                                                                                                                                                        |
| `community_export_revenue` | feed_in (community)     | `community_export_power`                                                                                                                                                        |

Each stored finance sensor adds one `:sum` record per day to `summary_values`. For a typical setup (house + heatpump + wallbox + 5 custom consumers), this adds roughly 22 records per day (about +46%). With energy community, roughly 24 records (about +50%).

**`summary_values.field` is a PostgreSQL enum** (`field_enum`), not a free-form string. Every new stored field needs an `add_enum_value :field_enum, :grid_costs, if_not_exists: true` migration — the pattern already exists (see `db/migrate/20250814094431_add_heatpump_sensors_to_summary_values.rb`). Counting all 20 custom consumers, this is ~55 new enum values (40 of them `custom_XX_costs_grid` / `custom_XX_costs_pv`), independent of how many rows a concrete installation actually writes. Enum values cannot be removed again, so the naming has to be right the first time.

`summary_values.value` is a `float`, while prices are `decimal`. The multiplication happens in Ruby/Flux and is stored as a float — the same precision the power sums already have. Money is never summed in decimal, which is fine for reporting but means the daily totals are not exact to the cent.

**Computed finance sensors** (derived from stored values, no price lookup needed):

| Sensor                       | Calculation                                   |
| ---------------------------- | --------------------------------------------- |
| `house_costs`                | `house_costs_grid` + `house_costs_pv`         |
| `heatpump_costs`             | `heatpump_costs_grid` + `heatpump_costs_pv`   |
| `wallbox_costs`              | `wallbox_costs_grid` + `wallbox_costs_pv`     |
| `custom_XX_costs`            | `custom_XX_costs_grid` + `custom_XX_costs_pv` |
| `grid_balance`               | `grid_revenue` - `grid_costs`                 |
| `solar_price`                | `grid_costs` - `grid_revenue`                 |
| `savings`                    | `traditional_costs` - `solar_price`           |
| `house_without_custom_costs` | proportional from `house_costs`               |
| `total_costs`                | `grid_costs` + `opportunity_costs`            |

---

## Price Lookup

To find the applicable price for a consumer on a given date:

```ruby
# 1. Look for a consumer-specific price
price = Price.where(name: :electricity, consumer: 'heatpump_power')
             .where(starts_at: ..date)
             .order(starts_at: :desc)
             .first

# 2. `inherit` explicitly ends the consumer-specific tariff
price = nil if price&.inherit?

# 3. Fall back to default price (consumer = 'all')
price ||= Price.where(name: :electricity, consumer: 'all')
               .where(starts_at: ..date)
               .order(starts_at: :desc)
               .first
```

This comes as a **new** method `Price.effective(name:, consumer:, date:)` returning a `Price` object, so the caller can inspect `mode`, `time_slots` and `base_fee`. The existing `Price.at(name:, date:)` (which `pick`s a decimal) stays as a thin wrapper: it is used by the MCP tool `get_prices` and by `Influx::FinanceCalculation`, and changing its return type would ripple further than necessary. Once all callers have moved to `.effective`, `.at` can go.

Lookups happen per day and per consumer, so the SummaryBuilder should load the price table once per run instead of issuing one query per finance sensor.

---

## Examples

### Example 1: Standard setup (one price, like today)

```
name=electricity  starts_at=2024-01-01  mode=fixed  value=0.30   consumer=all  base_fee=12.00
name=feed_in      starts_at=2024-01-01  mode=fixed  value=0.082  consumer=all
```

All consumers use 0.30 EUR/kWh with 12 EUR/month base fee. Equivalent to the current behavior (plus the new base fee).

### Example 2: Heat pump with separate price

```
name=electricity  starts_at=2024-01-01  mode=fixed  value=0.30  consumer=all             base_fee=12.00
name=electricity  starts_at=2024-01-01  mode=fixed  value=0.22  consumer=heatpump_power   base_fee=8.00
```

House, wallbox, etc. are billed at 0.30 EUR/kWh (12 EUR/month base fee). Heat pump at 0.22 EUR/kWh (8 EUR/month base fee). Total monthly base fee: 20 EUR.

### Example 3: Time-of-use (§14a module 3)

```
name=electricity  starts_at=2025-01-01  mode=time_of_use  consumer=all
  time_slots=[{"starts_at":"00:00","value":0.22},{"starts_at":"06:00","value":0.32},{"starts_at":"22:00","value":0.22}]
```

All consumers use HT/NT pricing: 0.22 EUR/kWh from 22:00-06:00, 0.32 EUR/kWh from 06:00-22:00.

### Example 4: Dynamic pricing (Tibber)

```
name=electricity  starts_at=2025-07-01  mode=dynamic  consumer=all
```

All consumers use Tibber spot prices from InfluxDB.

### Example 5: Mixed - Dynamic default + ToU heat pump

```
name=electricity  starts_at=2025-01-01  mode=dynamic          consumer=all
name=electricity  starts_at=2025-01-01  mode=time_of_use      consumer=heatpump_power
  time_slots=[{"starts_at":"00:00","value":0.19},{"starts_at":"06:00","value":0.29},{"starts_at":"22:00","value":0.19}]
```

House and wallbox use Tibber spot prices. Heat pump uses fixed time slots (module 3).

### Example 6: Dynamic feed-in (direct marketing)

```
name=feed_in  starts_at=2026-01-01  mode=dynamic  consumer=all
```

Feed-in revenue calculated from spot market prices in `feed_in_price` InfluxDB measurement.

### Example 7: Energy sharing / renewable energy community

In renewable energy communities (EEG in Austria, Energy Sharing in Germany), neighbors share solar power. A household's grid import and export are each split into a community portion and a regular portion.

The **consumption split** is determined externally by the grid operator's smart meter portal (typically as 15-minute interval data, available next day). The **price** is agreed upon separately in a static contract - the community is essentially an additional electricity supplier with its own rate. However, communities could also use dynamic or time-of-use pricing.

**New sensors** (written to InfluxDB by an external collector):

- `community_import_power` - power received from the community (subset of `grid_import_power`). This is consumption data, not price data.
- `community_export_power` - power fed into the community (subset of `grid_export_power`). This is consumption data, not price data.

Since this data typically arrives after the fact (next day), the SummaryBuilder can calculate the daily summary immediately upon import for the completed day. If the day's summary was already calculated without community data, it is deleted entirely and recalculated once the community data arrives.

**Price configuration:**

```
name=electricity  starts_at=2026-06-01  mode=fixed  value=0.30   consumer=all
name=electricity  starts_at=2026-06-01  mode=fixed  value=0.15   consumer=community_import_power
name=feed_in      starts_at=2026-06-01  mode=fixed  value=0.082  consumer=all
name=feed_in      starts_at=2026-06-01  mode=fixed  value=0.12   consumer=community_export_power
```

**Cost calculation:**

```
Grid import costs:
  community:  community_import_power x 0.15 / 1000
  regular:    (grid_import_power - community_import_power) x 0.30 / 1000

Feed-in revenue:
  community:  community_export_power x 0.12 / 1000
  regular:    (grid_export_power - community_export_power) x 0.082 / 1000
```

Note: This requires changes to the `grid_costs` and `grid_revenue` finance sensor definitions - they must subtract the community portion before applying the regular price. The community costs/revenue are calculated as separate finance sensors (`community_import_costs`, `community_export_revenue`).

### Example 8: Timeline with mode changes

```
2023-01-01  name=electricity  mode=fixed        value=0.25  consumer=all
2024-06-01  name=electricity  mode=fixed        value=0.30  consumer=all
2025-01-01  name=electricity  mode=time_of_use              consumer=all             time_slots=[...]
2025-01-01  name=electricity  mode=fixed        value=0.22  consumer=heatpump_power
2025-07-01  name=electricity  mode=dynamic                  consumer=all
2026-01-01  name=electricity  mode=fixed        value=0.28  consumer=all
```

When querying the full year 2025, the SQL path simply sums the daily cost values from `summary_values`. It does not need to know which pricing mode or consumer assignment was active on any given day.

---

## Calculation Paths

### SummaryBuilder (once per day)

For each finance sensor (e.g. `house_costs_grid`, `wallbox_costs_grid`, `grid_revenue`), the SummaryBuilder:

1. Determines, per dependency, which **consumer** the price is looked up for
2. Looks up the **price** for that consumer on that date (consumer-specific or default, see Price Lookup above)
3. Calculates costs based on the price mode:

Step 1 cannot simply reuse `depends_on`: several finance sensors have more than one dependency and mix price types (`battery_savings` pairs discharge×electricity with charge×feed_in, `opportunity_costs` uses `inverter_power - grid_export_power`), and `traditional_costs` declares `depends_on` as a **Proc** (it mirrors `total_consumption.dependencies`), so `static_dependencies` returns an empty array for it. The mapping therefore belongs into the definitions, next to `#required_prices` — e.g.

```ruby
# Sensor::Definitions::GridCosts
def price_inputs
  { grid_import_power: :electricity }   # consumption sensor => price type
end
```

The consumer key for the lookup is the consumption sensor itself for the dedicated consumers (`heatpump_power_grid` → tariff of `heatpump_power`), and `'all'` for everything aggregate (`grid_import_power`, `inverter_power`, …). `traditional_costs` is the interesting case: it sums house + heat pump + wallbox + excluded custom consumers, so with a separate heat pump tariff it has to price **each** dependency with that dependency's own price instead of applying one price to the sum. Its `#sql_calculation` does exactly this today (one `pb_money_per_kwh` for the whole sum) — that shortcut goes away.

```
                    Price for consumer on date
                              |
                          mode?
                              |
            +-----------------+-----------------+
            |                 |                 |
          fixed          time_of_use         dynamic
            |                 |                 |
            v                 v                 v
      daily integral    integral per       consumption
       from InfluxDB     time slot          series
            |            from InfluxDB      from InfluxDB
            v                 |                 |
        x fixed price         v                 v
        from PG          x slot price      x price series
            |            from PG            from InfluxDB
            |                 |                 |
            v                 v                 v
            +-----------------+-----------------+
                              |
                              v
              summary_values (sensor, :sum, daily_total)
```

**Fixed:**

```ruby
consumption = flux_integral(sensor, day)           # -> 5000 Wh
costs = consumption * price.value / 1000.0          # -> 1.50 EUR
```

**Time-of-Use:**

```ruby
price.time_slots.each do |slot|
  # Zone-aware: Time.zone.parse on the day, NOT UTC arithmetic
  time_range = day_date.combine(slot.starts_at, slot.next_starts_at)
  consumption = flux_integral(sensor, time_range)   # -> 2000 Wh
  costs += consumption * slot.value / 1000.0         # -> 0.60 EUR
end
```

Slot boundaries are local wall-clock times, so the ranges must be built in `Time.zone`, and the last slot ends at the **next day's** 00:00 local. On DST days that makes one slot an hour shorter or longer; the slots still tile the day without gaps or overlap, which is what matters. The same applies to the daily boundary itself, which `Timeframe` already handles.

**Dynamic:**

```ruby
# Load both time series from InfluxDB, align on 15min windows, multiply in Ruby
consumption_series = flux_query(sensor, day, window: 15m, fn: integral)
price_series = flux_query(electricity_price, day, window: 15m, fn: mean)
costs = zip(consumption_series, price_series).sum { |c, p| c * p / 1000.0 }
```

`zip` only works because both series are aggregated into the _same_ window. That holds for the daily summary, but not for `Sensor::Query::Series`, which renders charts at 30s (P1H) or 5min resolution — far below the 15min/1h price interval. There, the price series must be resampled to the chart interval and carried forward (`aggregateWindow(fn: last, createEmpty: true)` + `fill(usePrevious: true)`), otherwise most data points get a `nil` price. Aligning by index is fragile in either case: match by timestamp and treat a missing price as "no value", not as zero.

**Missing data handling:** If InfluxDB price data is missing for a dynamic day (e.g. the collector was down), the cost for that day is `nil` (not zero) and no summary value is written — consistent with how other sensors handle missing data. But with costs _stored_, a hole behaves differently than today: the SQL path just sums the rows that exist, so a month total silently under-reports instead of being obviously wrong, and the day is never retried because `Summary.missing_or_stale_days` works per day, not per field. Therefore: if a dynamic price is missing for a day whose consumption data is present, **do not write the day's summary at all** (or mark it stale), so it is recalculated once the price data arrives. This is the same mechanism Example 7 needs for late-arriving community data.

**Negative prices:** Spot prices can be negative (and with direct marketing, so can feed-in prices), so daily totals may be negative. `SummaryBuilder#clamp_values_to_sensor_ranges` clamps every stored value to the sensor's `value_range` — currently no finance sensor declares one, so `clamp_value` is a no-op for them. That must stay this way: finance sensors must not get a `(0..)` range when they become stored, otherwise negative days are silently clamped to zero.

### Base Fee Calculation

The monthly base fee is **not** stored in `summary_values` (which are per-day). Instead, it is added at display time for monthly or yearly views:

```ruby
# Collect all distinct base fees active during the month
# (default tariff + any consumer-specific tariffs)
total_base_fee = sum of all applicable base_fee values for the month

# Monthly view:
monthly_costs = summary_values_sum + total_base_fee

# Yearly view:
yearly_costs = summary_values_sum + sum_of_monthly_base_fees
```

For partial months (e.g. price change mid-month), each base fee is prorated: `base_fee * active_days / days_in_month`. When a tariff changes mid-month, both base fees are prorated and summed.

Base fees only apply to views that span full months or longer (monthly, yearly, total). For day and week views, no base fee is shown.

Base fees are intentionally **not** part of the `savings` sensor, so the amortization calculator (which combines measured `savings` with the manual `CashFlow` register) is unaffected. Users who want base fees reflected in their profitability calculation can record them as recurring cash flow entries — keeping them out of `savings` avoids double counting.

### SQL Path (queries for days, months, years)

Fundamental change: **No price JOIN needed anymore.** Finance sensors are regular stored fields in `summary_values` and are aggregated with `SUM()` - just like `house_power` or `grid_import_power`.

The `price_ranges` CTE and all price JOINs in `CteBuilder` are removed, along with the `required_prices` plumbing in `Sql::QueryBuilder` **and** in `Query::Ranking` (which builds the price CTE itself, for daily and period rankings alike). Since a stored sensor resolves to itself in `Base#storable_fields`, the ranking CTEs get simpler at the same time: `grid_costs` becomes a plain field instead of a derived expression over `grid_import_power`.

`#sql_calculation` disappears from the price-multiplying definitions. It stays where a money sensor is derived from other money sensors (`savings`, `solar_price`, `total_costs`), just without the `pb_`/`pf_` references.

Base fees are added in the application layer (not in SQL), since they are monthly constants.

### InfluxDB Path (hourly view and chart series)

For periods < 1 day, costs are calculated in Ruby using the same three-path logic. This concerns `Sensor::Query::Helpers::Influx::Total` (hourly totals) and `Sensor::Query::Series` (chart data points) — both include `Influx::FinanceCalculation`, so the three paths are implemented **once**, in that module, and both callers inherit them.

- **Fixed**: Each hour's consumption (from InfluxDB) is multiplied by the fixed price. Straightforward.
- **Time-of-Use**: Each hour is queried individually with a time range matching the hour boundaries. When a slot boundary falls within an hour (e.g. slot changes at 06:00, hour is 05:00–06:00), multiple InfluxDB queries are issued — one per sub-range with its respective slot price. No windowing is used; each query specifies explicit `start`/`stop` times.
- **Dynamic**: Both consumption and price series are loaded from InfluxDB for the requested time range and multiplied per interval (see the resampling note above for the chart series).

`FinanceCalculation#prices` currently resolves one price per type for the whole query (`Price.at(name:, date: timeframe.date)`). It has to become a lookup per consumer, and for ToU/dynamic a lookup per data point. Query results are cached (`Influx::Base#cache_key` over the query string), so the extra sub-range queries of the ToU path are cheap on repeat, but a fresh hourly view issues up to one query per slot boundary.

The result is returned directly (not stored in `summary_values`), since these views always query InfluxDB.

---

## Component Changes

| Component                              | Change                                                                                                                                                                                                                                                                     |
| -------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **`Price` model**                      | New columns `mode`, `time_slots`, `base_fee`, `consumer`. `value` becomes nullable. Uniqueness scope `%i[name consumer]`. New `Price.effective` returning a Price object; `Price.at` stays as wrapper                                                                      |
| **DB migration `field_enum`**          | ~55 `add_enum_value` calls for the new stored finance fields (`grid_costs`, `custom_XX_costs_grid`, …)                                                                                                                                                                     |
| **Finance sensor definitions**         | The price-multiplying ones (`FinanceBase` subclasses) get `stored: [:sum]` and a `price_inputs` mapping; the derived ones (`savings`, `solar_price`, `grid_balance`, `house_without_custom_costs`) stay computed                                                           |
| **`SummaryBuilder`**                   | New finance calculation: resolve price per consumer, then three paths (fixed/tou/dynamic). Finance sensors are neither `watt_sensors_for_sum` nor `calculated?`, so they need their own collection step                                                                    |
| **`SummaryInvalidator`**               | Bump `version:` in `build_config` once at rollout — that is the existing mechanism for wiping now-invalid summaries                                                                                                                                                        |
| **`Sql::CteBuilder` / `QueryBuilder`** | Price CTE and price JOINs removed                                                                                                                                                                                                                                          |
| **`Query::Ranking`**                   | Builds its own price CTE today — removed as well; rankings read the stored field directly                                                                                                                                                                                  |
| **`FinanceBase`**                      | `sql_calculation` and `calculate_with_prices` removed long-term                                                                                                                                                                                                            |
| **`Influx::FinanceCalculation`**       | Three paths for the sub-day views; shared by `Influx::Total` (hourly) and `Query::Series` (charts), so implemented once                                                                                                                                                    |
| **Settings UI**                        | Price form: mode selector, ToU time slot editor, consumer assignment, base fee input. `prices_controller` permitted params, and the list/broadcast must group by `consumer`                                                                                                |
| **Collector**                          | External collector for spot prices -> writes to `electricity_price` / `feed_in_price`                                                                                                                                                                                      |
| **`AmortizationCalculator`**           | No structural change (reads monthly `savings` via the SQL path), but its cache key is `[Date.current, CashFlow.cache_key_with_version, period, interest]` — it must also include `Price.all.cache_key_with_version`, otherwise a price edit stays invisible until midnight |
| **MCP server (`get_prices`)**          | Currently assumes one fixed value per entry; must expose `mode`, `time_slots`, `base_fee`, `consumer`                                                                                                                                                                      |

---

## Open Questions

- **Consumer key for power-splitter sensors.** A heat pump tariff is configured on `heatpump_power`, but the cost sensors consume `heatpump_power_grid` and `heatpump_power - heatpump_power_grid`. The lookup has to strip the `_grid` suffix (or go through `corresponding_base_sensor`) — the split into grid/PV share is a splitter concept, not a tariff concept.
- **`traditional_costs` with consumer tariffs.** "What would this have cost without PV" is ambiguous once the heat pump has its own contract: keep pricing each consumer with its own tariff (chosen here), or price everything with the household tariff? The former is more truthful, the latter matches how the sensor is usually read. Affects `savings` and therefore the amortization calculation.
- **`grid_costs` vs. the sum of the consumer costs.** With one price they are identical up to rounding; with per-consumer tariffs they are not, because `grid_import_power` is priced with the `'all'` tariff while its consumer-level shares use their own. Either `grid_costs` becomes the sum of the consumer parts, or the two are documented as answering different questions.
- **ToU/dynamic and the daily boundary.** Both need sub-daily consumption data for a day that has already been summarized. This is fine for the SummaryBuilder (it queries InfluxDB anyway), but it rules out ever computing finance sensors from the stored daily sums.

---

## Migration Plan

Phase 1 is the only phase that is not backwards-compatible on its own: it moves the money from "computed at query time" to "stored per day". Everything after that adds modes on top of the same storage.

### Phase 1 - Pre-calculated Costs (Fixed only)

1. Add `mode` column to `prices` (default: `fixed`), make `value` nullable
2. Add `time_slots`, `base_fee`, `consumer` columns to `prices`
3. Change unique index from `(name, starts_at)` to `(name, starts_at, consumer)`
4. Add the new stored finance fields to the `field_enum` type (`add_enum_value`, `if_not_exists: true`) — enum values cannot be removed later
5. Change the price-multiplying finance sensors to `stored: [:sum]`
6. `SummaryBuilder` calculates finance sensors (fixed path, default price)
7. Bump `version:` in `SummaryInvalidator.build_config`. This wipes all existing summaries via `Summary.reset!` (which also clears the Rails cache); they are rebuilt lazily per requested timeframe by `SummaryChecker`
8. Switch SQL path: read costs directly from `summary_values`
9. When a price is created/modified/deleted, delete the complete daily summaries from that price's `starts_at` onward (up to the next entry for the same `consumer`). Summaries are always deleted and rebuilt as a whole (all sensors for a day), never partially. They will be re-calculated on demand. Note that a targeted delete does **not** clear the Rails cache, so the amortization result must be invalidated separately (see Component Changes).

**Rebuild cost:** a full wipe means re-querying InfluxDB for every day since the installation date — for a five-year installation that is ~1,800 Flux queries, spread over whatever timeframes the user actually opens. It also assumes the raw data is still there; that holds today (SOLECTRUS keeps InfluxDB data indefinitely), but it is the load-bearing assumption behind "rebuilt on demand" and should be verified before shipping Phase 1.

### Phase 2 - Consumer-Specific Prices

10. UI for creating prices with `consumer` field (incl. `inherit` to end a consumer tariff)
11. `price_inputs` mapping in the finance definitions; `SummaryBuilder` resolves the price per dependency before calculation
12. Re-summarize affected days

### Phase 3 - Time-of-Use

13. Implement ToU path in SummaryBuilder (zone-aware slot ranges)
14. Implement ToU path in `Influx::FinanceCalculation` (sub-day views)
15. UI for time slot editor (time slot + price pairs)

### Phase 4 - Dynamic

16. Implement dynamic path in SummaryBuilder
17. Implement dynamic path in `Influx::FinanceCalculation`, including resampling the price series to the chart interval
18. Define InfluxDB measurements for prices
19. Integration with Tibber collector (already exists)

Dynamic mode can only produce costs for days the price collector has actually written. History before that stays on `fixed`/`time_of_use` entries — which the timeline model handles naturally, since `mode` changes with `starts_at`. The UI should say so, otherwise users will switch the whole history to `dynamic` and lose it.

### Phase 5 - Base Fee and Direct Marketing

20. Base fee display in monthly/yearly cost views
21. Dynamic feed-in support (direct marketing)

### Phase 6 - Energy Sharing / Renewable Energy Communities

22. New sensor definitions for `community_import_power` and `community_export_power`
23. New finance sensors `community_import_costs` and `community_export_revenue`
24. Modify `grid_costs` and `grid_revenue` to subtract community portions
25. Collector for smart meter portal data
