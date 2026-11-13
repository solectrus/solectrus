# Sub-Day Prices

Tariffs whose price changes within a day: fixed time slots (time-of-use) and spot market prices (dynamic). They share one mechanism.

Blocks B and C in the [roadmap](roadmap.md#block-b--influxdb). Requires [01](01-stored-costs.md). Issues #4832 (time-of-use, §14a EnWG module 3), #2150 (Tibber, aWATTar), #4947 (dynamic feed-in, direct marketing).

## Data model

A price entry gains a `mode`:

| Mode          | Amount per kWh | Slots       |
| ------------- | -------------- | ----------- |
| `fixed`       | required       | must be nil |
| `time_of_use` | must be nil    | required    |
| `dynamic`     | must be nil    | must be nil |
| `inherit`     | must be nil    | must be nil |

`inherit` is only valid for a consumer tariff ([02](02-consumer-tariffs.md#ending-a-consumer-tariff)).

The amount column becomes nullable in the database and the model. Never store zero for "no amount": zero is a real spot price. An older SOLECTRUS version then reads nil for such a row and shows blank money figures for those dates; say so in the release notes.

A slot is a start time and an amount, in order:

```json
[
  { "starts_at": "00:00", "value": 0.22 },
  { "starts_at": "06:00", "value": 0.32 },
  { "starts_at": "22:00", "value": 0.22 }
]
```

- Each slot runs until the next one; the last until midnight. The first starts at 00:00.
- **Slots start on the full hour.** The time-of-use window is one hour, so a 06:30 slot would put one hour of energy into two prices. §14a module 3 and every published time-of-use tariff use full hours. Whoever relaxes this validation must shrink the window in the same commit.
- Slot times are local wall-clock times. A DST day has 23 or 25 hours; build the ranges in the local zone, as `Timeframe` does.

## Price sensors

Dynamic mode reads prices from InfluxDB through two ordinary registry sensors, `electricity_price` and `feed_in_price`, mapped by `INFLUX_SENSOR_*` like every other sensor. No hardcoded measurement, so any collector works.

- Unit `money_per_kwh`, the average is the only allowed aggregation, never stored in a summary.
- One series per tariff name. All consumers on a dynamic electricity tariff share it.
- **Never in `depends_on` of a cost sensor.** `Sensor::Config#exists?` would drop every cost sensor on installations without a spot price collector, which is most of them. The caller asks for the series when the tariff mode of the period says `dynamic`.
- The form refuses `dynamic` while the price sensor is not configured, and names the missing variable.
- The collector never backfills, so `dynamic` cannot produce costs before it was started. The form warns when an old entry is switched to `dynamic`.
- Every amount is gross, in Settings and from `tibber-collector`. State it in `docs/sensor-reference.md` and in the price sensor descriptions; do not model net amounts.

## Shape times amount

The obvious approach, an energy integral per slot or quarter hour times its price, is wrong here twice. The sum of the sub-day integrals is the raw energy, not the corrected daily value, so stored cost and stored energy would disagree. And a windowed integral defeats the InfluxDB pushdown (4–11× slower, see `Influx::DailyBatch`).

So the sub-day query asks only for the **shape** of the day, and the amount comes from the corrected daily value:

1. Query one mean power per window.
2. Per priced term, build the term per window (with its clamp), then normalize to weights.
3. Split the stored daily value of the term by those weights.
4. Multiply each window by its price and sum.

The window energies add up to the stored daily value by construction, so every correction carries over. Time-of-use and dynamic are the same code with a different price vector; fixed needs no query because the weights cancel.

- **One shape per term, never per dependency.** A clamp does not survive being taken apart: Σ max(a − b, 0) ≠ max(Σa − Σb, 0). The priced terms of [01](01-stored-costs.md#priced-terms) are evaluated per window, so this comes for free.
- **A shape that sums to zero** (the corrector can create a daily value the raw data never had): spread the daily value evenly over the windows with data. Otherwise the division yields `NaN`, which a float column accepts silently.
- The window count comes from the timeframe (DST days), never from a constant.
- A mean is sample-weighted. With a constant collector interval that does not matter; check it against real data.

## The tariff sets the window

| Mode          | Window     |
| ------------- | ---------- |
| `fixed`       | no query   |
| `time_of_use` | one hour   |
| `dynamic`     | 15 minutes |

Time-of-use on an hourly window is exact, because slots start on the hour, and returns a quarter of the rows. Dynamic must not use an hourly window: that averages the price over the hour and removes exactly the load shifting a dynamic tariff is bought for.

## Two arithmetic traps

- **Multiply at the price resolution, then sum.** An hour costs the sum of four quarter-hour products, not hourly energy times mean price. The difference is a systematic error against shifted load.
- **Timestamps.** The collector stamps each price at the start of its interval, while a windowed aggregate is right-aligned by default. Align the windows to the price grid and carry a price forward; never interpolate.

## Query cost

The shape query is one more stream per day inside the program `Influx::DailyBatch` already sends: one query per chunk of days, never one per day or slot. Dynamic adds one query per chunk for the price series.

The cost is in the rows. One sensor and day return one row per window instead of one. So:

- Window only the sensors a cost term is made of: grid pair, `inverter_power`, battery pair, priced consumers and their `_grid` shares. 13 sensors without custom consumers, 53 with all 20. At 96 windows over seven days that is up to 36,000 rows per response.
- Benchmark the Ruby parse too, not only InfluxDB.
- Where a per-day stream of 5-minute means already exists (sensors declaring min/max/avg), the shape is a fourth branch of it. The `_grid` shares and `custom_power_XX` declare a sum only and need a stream of their own; that group is the larger one with custom consumers.

**Today is the hot path.** The summary of today goes stale after minutes and is rebuilt alone, without the batch, while the user watches. Measure that path on its own. Price series of finished days never change, so they can be cached; today's cannot.

## The sub-day views

`Influx::FinanceCalculation` serves both views and needs a price lookup per consumer and mode.

- **Chart series** (points every 5 min or 30 s): resample the price series to the chart interval, carry forward, match by timestamp. A missing price is no value, never zero.
- **Hourly totals** (1–99 h, one number): split the timeframe at the price boundaries, take one energy per window, multiply, sum. No batch needed, the window count is small. This is the part most easily mistaken for done. Price by the window, not by `timeframe.date`, which is today.

## Charging sessions and the heat pump comparison

Both are priced with a simplification: the **time-weighted mean price** over their window, assuming constant power. No power query.

- A charging session uses its exact start and end. A wallbox charges at nearly constant power, so the error is small. A time-of-use edit reprices sessions from stored data, inline, as today.
- The "without PV" column of `Heatpump::Comparison` uses the mean price of the day. It ignores when the heat pump ran, so it does not reward load shifting. That is acceptable for a hypothetical comparison and is stated on the page.

## Missing data

When the price series of a dynamic day is missing, its costs are nil and no cost row is written. The day itself is written, so its energy stays visible.

Such a day would count as fresh and never retry. So the summary gets a marker: since when a cost was omitted. A day is stale while the marker is set and younger than one week; after that it stops retrying and the marker tells the UI why it is incomplete. The marker is cleared when the day is written complete.

Both staleness checks need the marker: `Summary.missing_or_stale_days` and `Summary#stale?`. Teaching only the SQL lists the day and then drops it again in Ruby.

Never fall back to the last known price.

## MCP

`get_prices` reports the agreed tariff, the price sensors the measured curve. Both descriptions say so.

- A time-of-use entry carries its slots; a dynamic entry only its mode and points at the price sensor. The mode disambiguates an empty amount from "no tariff". Entries without an amount sort last.
- The price sensors appear in `list_sensors`, so `get_series` can answer "when was electricity cheapest today".
- _Stop point 4:_ `get_totals` uses SQL for a day or longer, and a never-stored sensor has no row there. Either `t` becomes per timeframe for every sensor, or the price sensors never claim it.

Run `bin/llm-test` after every description change, and `--ablate` before adding a sentence.

## Traps

- Shape per dependency instead of per term: equal-slot time-of-use stops matching fixed. The equivalence spec catches it.
- Shape sums to zero: `NaN` in the summary.
- Price sensor in `depends_on`: all cost sensors vanish without a collector.
- Hourly totals priced with one amount: wrong for every sub-day mode.
- Missing-data marker taught to one staleness check only: no retry.
- Slots between full hours: the hourly window prices at a rate the tariff never had.
