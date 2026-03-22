# Dynamic Pricing Concept

## Related Issues / Discussions

- #2150 - Dynamic tariffs (Tibber, aWATTar)
- #2560 - Monthly base fee
- #2797 - Currency configuration (e.g. CHF instead of EUR)
- #4832 - Time-of-use tariffs (§14a EnWG, module 3)
- #4850 - Consumer-specific tariffs
- #4947 - Dynamic feed-in tariffs (direct marketing)
- #5227 - Heat pump electricity tariffs
- #5334 - Renewable energy communities / energy sharing (multiple suppliers)

## Current State

Prices are stored in PostgreSQL (`prices` table) with a fixed value per kWh, valid from a start date. There is one electricity price and one feed-in price at any given time, applying equally to all consumers. Costs are calculated at query time: the SQL path uses price JOINs via CTEs, the InfluxDB path multiplies in Ruby.

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
- The **currency** is configurable (e.g. CHF instead of EUR)

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
name:       enum (electricity / feed_in)                            (existing, unchanged)
starts_at:  date, not null                                          (existing)
mode:       enum (fixed / time_of_use / dynamic), default: fixed    (new)
value:      decimal, nullable                                       (existing, becomes nullable)
time_slots: jsonb, nullable                                         (new, only for time_of_use)
base_fee:   decimal, nullable                                       (new, monthly base fee)
consumer:   string, not null, default: 'all'                         (new)
note:       string, nullable                                        (existing)
```

**Column details:**

- `name`: Unchanged. `electricity` for grid purchase prices, `feed_in` for feed-in tariffs.
- `mode`:
  - `fixed` - `value` contains the price per kWh (as before)
  - `time_of_use` - `value` is `nil`, time slots with prices are defined in `time_slots`
  - `dynamic` - `value` is `nil`, prices come from InfluxDB
- `time_slots`: JSON array for time-of-use mode, e.g. `[{"starts_at": "00:00", "value": 0.20}, {"starts_at": "06:00", "value": 0.30}, {"starts_at": "22:00", "value": 0.20}]`. Each slot runs from its `starts_at` until the next slot's `starts_at` (or `"24:00"` / end-of-day for the last entry). The `next_starts_at` is derived at runtime from the array order — it is not stored.
- `base_fee`: Monthly fixed cost in the configured currency (meter fee, service charge, etc.). Applies from `starts_at` until the next entry. Can change over time independently of the kWh price. Each price entry with a base_fee represents a separate contract/meter. When displaying monthly costs, all applicable base fees are summed (e.g. default tariff 12 + heat pump tariff 8 = 20/month total).
- `consumer`: When `'all'`, this price applies to all consumers without a specific entry. When set to a specific sensor name (e.g. `heatpump_power`, `wallbox_power`), this price applies only to that consumer. Stored as a **string** (not an enum) so new sensor types can be added without code changes. Validated against the list of configured power sensors at runtime.

**Unique index** changes from `(name, starts_at)` to `(name, starts_at, consumer)`:

```sql
CREATE UNIQUE INDEX index_prices_uniqueness
  ON prices (name, starts_at, consumer)
```

**Validation rules:**

- `fixed`: `value` required, `time_slots` must be nil
- `time_of_use`: `time_slots` required, `value` must be nil. First entry must start at `"00:00"`, entries must be in chronological order, and must cover the full 24 hours.
- `dynamic`: both `value` and `time_slots` must be nil
- `base_fee`: optional for all modes, must be >= 0 when present

### InfluxDB (new, only for Dynamic mode)

```
Measurement: electricity_price   field: price_per_kwh
Measurement: feed_in_price       field: price_per_kwh
```

Written by an external collector (Tibber API, aWATTar API, etc.). Interval depends on provider (15min or 1h). The Tibber collector already exists and writes to InfluxDB.

For dynamic mode, the InfluxDB measurement is determined by `name`: `electricity` reads from `electricity_price`, `feed_in` reads from `feed_in_price`. This applies regardless of the `consumer` field - all consumers with dynamic electricity pricing share the same spot price series.

### Currency

The currency is a global setting (environment variable, e.g. `CURRENCY=CHF`), defaulting to `EUR`. It affects:

- Display: All monetary values are formatted with the configured currency symbol
- Price input: Labels and placeholders show the configured currency
- Calculations: No change needed — all formulas work in the configured currency unit, since prices and costs are always in the same currency

All columns storing monetary values (`value`, `base_fee`, and finance sensor values in `summary_values`) are stored as plain decimals without currency reference. The currency is purely a display concern.

### `summary_values` (extended)

Finance sensors change from computed to **stored** sensors. Their daily cost totals are written directly to `summary_values`.

**Stored finance sensors** (price × consumption, calculated by SummaryBuilder):

| Sensor                     | Price                   | Consumption sensor                                                             |
| -------------------------- | ----------------------- | ------------------------------------------------------------------------------ |
| `grid_costs`               | electricity             | `grid_import_power`                                                            |
| `grid_revenue`             | feed_in                 | `grid_export_power`                                                            |
| `house_costs_grid`         | electricity             | `house_power_grid`                                                             |
| `house_costs_pv`           | feed_in                 | `house_power` - `house_power_grid`                                             |
| `heatpump_costs_grid`      | electricity             | `heatpump_power_grid`                                                          |
| `heatpump_costs_pv`        | feed_in                 | `heatpump_power` - `heatpump_power_grid`                                       |
| `wallbox_costs_grid`       | electricity             | `wallbox_power_grid`                                                           |
| `wallbox_costs_pv`         | feed_in                 | `wallbox_power` - `wallbox_power_grid`                                         |
| `custom_costs_XX_grid`     | electricity             | `custom_power_XX_grid` (per custom consumer)                                   |
| `custom_costs_XX_pv`       | feed_in                 | `custom_power_XX` - `custom_power_XX_grid`                                     |
| `battery_charging_costs`   | electricity             | `battery_charging_power_grid`                                                  |
| `battery_savings`          | electricity + feed_in   | `battery_discharging_power`, `battery_charging_power`                          |
| `opportunity_costs`        | feed_in                 | `inverter_power` - `grid_export_power` (self-consumed solar)                   |
| `traditional_costs`        | electricity             | total consumption (`house_power` + optional `heatpump_power`, `wallbox_power`) |
| `community_import_costs`   | electricity (community) | `community_import_power`                                                       |
| `community_export_revenue` | feed_in (community)     | `community_export_power`                                                       |

Each stored finance sensor adds one `:sum` record per day to `summary_values`. For a typical setup (house + heatpump + wallbox + 5 custom consumers), this adds ~22 records per day (~+46%). With energy community, ~24 records (~+50%).

**Computed finance sensors** (derived from stored values, no price lookup needed):

| Sensor                       | Calculation                                 |
| ---------------------------- | ------------------------------------------- |
| `house_costs`                | `house_costs_grid` + `house_costs_pv`       |
| `heatpump_costs`             | `heatpump_costs_grid` + `heatpump_costs_pv` |
| `wallbox_costs`              | `wallbox_costs_grid` + `wallbox_costs_pv`   |
| `custom_costs`               | `custom_costs_grid` + `custom_costs_pv`     |
| `grid_balance`               | `grid_revenue` - `grid_costs`               |
| `solar_price`                | `grid_costs` - `grid_revenue`               |
| `savings`                    | `traditional_costs` - `solar_price`         |
| `house_without_custom_costs` | proportional from `house_costs`             |
| `total_costs`                | `grid_costs` + `opportunity_costs`          |

---

## Price Lookup

To find the applicable price for a consumer on a given date:

```ruby
# 1. Look for a consumer-specific price
price = Price.where(name: :electricity, consumer: :heatpump_power)
             .where(starts_at: ..date)
             .order(starts_at: :desc)
             .first

# 2. Fall back to default price (consumer = 'all')
price ||= Price.where(name: :electricity, consumer: :all)
               .where(starts_at: ..date)
               .order(starts_at: :desc)
               .first
```

This replaces the current `Price.at(name:, date:)` method which returns a decimal value. The new method returns a `Price` object so the caller can inspect `mode`, `time_slots`, and `base_fee`.

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

1. Determines the **consumer sensor** via the existing `depends_on` declaration (e.g. `GridCosts` depends on `grid_import_power`, `HouseCostsGrid` depends on `house_power_grid`)
2. Looks up the **price** for that consumer on that date (consumer-specific or default, see Price Lookup above)
3. Calculates costs based on the price mode:

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
  time_range = day_date.combine(slot.starts_at, slot.next_starts_at)
  consumption = flux_integral(sensor, time_range)   # -> 2000 Wh
  costs += consumption * slot.value / 1000.0         # -> 0.60 EUR
end
```

**Dynamic:**

```ruby
# Load both time series from InfluxDB, align on 15min windows, multiply in Ruby
consumption_series = flux_query(sensor, day, window: 15m, fn: integral)
price_series = flux_query(electricity_price, day, window: 15m, fn: mean)
costs = zip(consumption_series, price_series).sum { |c, p| c * p / 1000.0 }
```

**Missing data handling:** If InfluxDB price data is missing for a dynamic day (e.g. collector was down), the cost for that day is `nil` (not zero). The summary value is not written, which is consistent with how other sensors handle missing data.

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

### SQL Path (queries for days, months, years)

Fundamental change: **No price JOIN needed anymore.** Finance sensors are regular stored fields in `summary_values` and are aggregated with `SUM()` - just like `house_power` or `grid_import_power`.

The `price_ranges` CTE and all price JOINs in `CteBuilder` are removed.

Base fees are added in the application layer (not in SQL), since they are monthly constants.

### InfluxDB Path (hourly view)

For periods < 1 day (hourly view), costs are calculated per hour using the same three-path logic:

- **Fixed**: Each hour's consumption (from InfluxDB) is multiplied by the fixed price. Straightforward.
- **Time-of-Use**: Each hour is queried individually with a time range matching the hour boundaries. When a slot boundary falls within an hour (e.g. slot changes at 06:00, hour is 05:00–06:00), multiple InfluxDB queries are issued — one per sub-range with its respective slot price. No windowing is used; each query specifies explicit `start`/`stop` times.
- **Dynamic**: Both consumption and price series are loaded from InfluxDB for the requested time range and multiplied per interval.

The result is returned directly (not stored in `summary_values`), since hourly views always query InfluxDB.

---

## Component Changes

| Component                      | Change                                                                                                                                                  |
| ------------------------------ | ------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **`Price` model**              | New columns `mode`, `time_slots`, `base_fee`, `consumer`. `value` becomes nullable. New validations. `Price.at` returns Price object instead of decimal |
| **Finance sensor definitions** | `stored: [:sum]` instead of `stored: false`                                                                                                             |
| **`SummaryBuilder`**           | New finance calculation: resolve price per consumer, then three paths (fixed/tou/dynamic)                                                               |
| **`CteBuilder`**               | Price CTE and price JOINs removed                                                                                                                       |
| **`FinanceBase`**              | `sql_calculation` and `calculate_with_prices` removed long-term                                                                                         |
| **`Influx::Total`**            | Finance calculation analogous to SummaryBuilder for hourly view                                                                                         |
| **Settings UI**                | Price form: mode selector, ToU time slot editor, consumer assignment, base fee input                                                                    |
| **Collector**                  | External collector for spot prices -> writes to `electricity_price` / `feed_in_price`                                                                   |

---

## Migration Plan

### Phase 1 - Pre-calculated Costs (Fixed only)

1. Add `mode` column to `prices` (default: `fixed`), make `value` nullable
2. Add `time_slots`, `base_fee`, `consumer` columns to `prices`
3. Change unique index from `(name, starts_at)` to `(name, starts_at, consumer)`
4. Change finance sensors to `stored: [:sum]`
5. `SummaryBuilder` calculates finance sensors (fixed path, default price)
6. Delete all existing daily summaries; they will be rebuilt on demand (summaries are always rebuilt as a whole, not per sensor)
7. Switch SQL path: read costs directly from `summary_values`
8. When a price is created/modified/deleted, delete the complete daily summaries from that price's `starts_at` onward (up to the next price entry's `starts_at`). Summaries are always deleted and rebuilt as a whole (all sensors for a day), never partially. They will be re-calculated on demand.

### Phase 2 - Consumer-Specific Prices

9. UI for creating prices with `consumer` field
10. `SummaryBuilder` resolves price per consumer before calculation
11. Re-summarize affected days

### Phase 3 - Time-of-Use

12. Implement ToU path in SummaryBuilder
13. UI for time slot editor (time slot + price pairs)

### Phase 4 - Dynamic

14. Implement dynamic path in SummaryBuilder
15. Define InfluxDB measurements for prices
16. Integration with Tibber collector (already exists)

### Phase 5 - Base Fee and Direct Marketing

17. Base fee display in monthly/yearly cost views
18. Dynamic feed-in support (direct marketing)

### Phase 6 - Energy Sharing / Renewable Energy Communities

19. New sensor definitions for `community_import_power` and `community_export_power`
20. New finance sensors `community_import_costs` and `community_export_revenue`
21. Modify `grid_costs` and `grid_revenue` to subtract community portions
22. Collector for smart meter portal data
