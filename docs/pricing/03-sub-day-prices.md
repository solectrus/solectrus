# Sub-Day Prices

Tariffs whose price changes inside a day: fixed time slots (time-of-use) and spot market prices (dynamic). They share one mechanism, so they share one document.

Prerequisite reading: [current-state.md](current-state.md). **Requires** [01-stored-costs.md](01-stored-costs.md). No version of these features fits the current model, because a daily energy sum cannot say how much fell into the expensive hours.

Issues: #4832 (time-of-use, §14a EnWG module 3), #2150 (Tibber, aWATTar), #4947 (dynamic feed-in for direct marketing).

## Data model

A price entry gains a `mode`, the amount becomes optional, and a time-of-use entry carries its slots instead:

| Mode          | Amount             | Slots       |
| ------------- | ------------------ | ----------- |
| `fixed`       | the amount per kWh | must be nil |
| `time_of_use` | must be nil        | the slots   |
| `dynamic`     | must be nil        | must be nil |
| `inherit`     | must be nil        | must be nil |

`inherit` belongs to [02-consumer-tariffs.md](02-consumer-tariffs.md) and is only valid for a consumer tariff.

"The amount becomes optional" is two changes and not one. The column is `NOT NULL` in the database, and the model validates its presence. Both have to give way, and the presence rule becomes conditional on the mode. Do not let the mode carry a zero amount instead. Zero is a real price, because a day at the spot market can cost nothing. A column that cannot tell "no amount" from "no cost" cannot be repaired later.

**A downgrade then reads a NULL amount.** [A1](roadmap.md#a1--the-monthly-base-fee) already keeps the column name unchanged, so that an older SOLECTRUS version stays readable. This is the same question with a worse answer. The lookup of an older version returns nil for such a row. Every finance sensor then returns nil for the dates it covers, and the money figures are simply blank. Nothing raises, nothing warns, and the data is intact when the user upgrades again. That outcome is acceptable. Leaving it undocumented is not. Say it in the release notes of the version that ships the mode, next to the sentence about resetting the summaries (see [01-stored-costs.md](01-stored-costs.md#rollback-is-not-supported)).

A slot is a start time and an amount, and the list is chronological:

```json
[
  { "starts_at": "00:00", "value": 0.22 },
  { "starts_at": "06:00", "value": 0.32 },
  { "starts_at": "22:00", "value": 0.22 }
]
```

Each slot runs until the next one starts, and the last one until the end of the day. The end is derived from the order, never stored. The first entry must start at midnight, and the slots must cover the full day with no gap and no overlap.

**A slot must start on the full hour.** That is a validation, and without it the feature is quietly wrong. The shape query runs on an hourly window (see [the tariff sets the window](#the-tariff-sets-the-window)). A slot that starts at 06:30 puts one hour of energy into two prices, and the code picks one of them, at a rate no tariff ever had. The two rules have to be decided together. Either the slots are restricted to the hour, or the window follows the finest boundary a slot uses and a half-hour tariff costs twice the rows. Restrict the slots. §14a module 3 works on full hours, and so does every published time-of-use tariff, so the restriction costs nothing that exists.

Slot boundaries are **local wall-clock times**. On a DST day one slot is an hour shorter or longer, and the day has 23 or 25 hours. Build the ranges in the local zone, and let the last slot end at the local midnight of the next day. `Timeframe` already treats a daily boundary that way.

## The price series in InfluxDB

Dynamic mode reads its prices from InfluxDB. They are two ordinary registry sensors, `electricity_price` and `feed_in_price`. They are mapped through the same `INFLUX_SENSOR_*` contract as every other sensor, with the unit `money_per_kwh` that already exists.

An earlier draft hardcoded the measurement and field. No collector writes those names. `solectrus/tibber-collector` writes to a measurement that its own configuration names. A fixed name would force every user to reconfigure the collector, and it would lock out aWATTar and every other source. Going through the normal contract means that `Sensor::Config`, the query helpers and HELIOS need no special case at all.

Two properties differ from a power sensor:

1. **The aggregation is the average**, because summing a price is meaningless. Declaring it as the only allowed one is enough. The unit prefers a sum, but the preference gives way when the sum is not allowed. Do not change the unit mapping itself, because it decides the aggregation of every money sensor.
2. **It is never stored in a summary.** The daily average of a spot price is not a useful number, and the stored cost already carries the price that produced it.

The price sensor follows the tariff name, not the consumer. Every consumer on a dynamic electricity tariff shares the same spot price series.

### A price sensor is a query input, never a dependency

Do not put `electricity_price` into the `depends_on` of a finance sensor. It reads as the obvious way to make the query fetch it, and it deletes the sensor.

`Sensor::Config#exists?` treats a sensor with a SQL calculation as existing only while **all** of its static dependencies exist (see [current-state.md](current-state.md#the-details-that-break-things)). Nobody without a spot price collector has an `INFLUX_SENSOR_ELECTRICITY_PRICE` mapping. `grid_energy_costs` would fail that test and leave the registry, the menu, the summary and every query. The whole cost section of the application would disappear for every installation on a fixed tariff, which is most of them.

A Proc dependency escapes that test, because `static_dependencies` returns an empty array for one. It is still the wrong shape. The need for the price series does not come from the configuration. It comes from the mode of a tariff row, and a user edits that row in Settings. `Sensor::Config` is built once at boot, so a dependency list that reads the `prices` table answers with whatever was true at the last restart.

So the price series is fetched the way a price has always been fetched. The caller resolves the tariff for the period, and asks for the series when the mode says dynamic. That is one place in the summary step and one in `Influx::FinanceCalculation`. Neither touches the registry.

### Dynamic without a price sensor

The two are configured in different places, so they will be out of step. A user can select `dynamic` in Settings while no `INFLUX_SENSOR_*` mapping for the price sensor exists. The tariff is then a mode with nothing behind it. Every cost of every affected day is nil, forever. The [grace period](#missing-data) never expires into anything better, because no data is coming.

The form knows enough to prevent it. `Sensor::Config.exists?` answers whether the price sensor is configured, at the moment the mode is chosen. Refuse the mode there, and say which environment variable is missing. A validation is worth more here than a warning, because the alternative is a tariff that silently produces no money at all.

### The collector writes no history

`tibber-collector` fetches today and tomorrow on every run, at quarter-hourly resolution. It stamps each point at the **start** of its interval. It never backfills.

Two consequences follow. Dynamic mode can never produce costs for a day before the collector was started, so the history stays on `fixed` or `time_of_use` entries. The timeline model handles that, because the mode changes with the start date. But the form has to say so where the mode is switched. Otherwise a user sets the oldest entry to `dynamic` and loses years of cost history.

And an outage leaves a hole that nothing repairs. See "Missing data" below.

## Shape times amount

This is the core of the file. Get it wrong and both correctness and performance suffer.

The obvious approach is to query an energy integral per slot (time-of-use) or per quarter hour (dynamic), and to multiply each by its price. It is correct on paper and wrong in this codebase, for two independent reasons.

**Correctness.** The stored daily energy is not the raw integral. The cleanup stage and `SummaryCorrector` rewrite it, sometimes by a lot (see [current-state.md](current-state.md#the-details-that-break-things)). The sum of the sub-day integrals is the raw number, so the stored cost would no longer match the stored kWh. A user who compares `heatpump_power_grid` with `heatpump_costs_grid` finds an implied rate that matches no tariff they ever had.

**Speed.** `Influx::DailyBatch` records that a windowed integral defeats the InfluxDB pushdown and was 4 to 11 times slower than explicit per-day ranges. A windowed integral is exactly the function that warning is about.

Both problems disappear if the sub-day query answers a different question. Do not ask it for the energy. Ask it only for the **shape** of the day, and take the **amount** from the daily sum that is already stored and already corrected:

1. Query one mean power per window. A windowed mean keeps its pushdown, and it is the pipeline the daily batch already runs.
2. Normalize it. Only the relative distribution over the day is used, so the absolute values drop out.
3. Split the corrected daily energy by those weights. That gives the energy of each window.
4. Multiply each window by the price of that window, and sum.

Three things follow:

1. The window energies add up to the stored daily value by construction, so the stored cost always matches the stored energy. Every correction propagates for free, with no second code path.
2. Time-of-use and dynamic become the same code. Time-of-use is the case where the price vector is piecewise constant. Fixed is the case where it is constant, the weights cancel out, and no sub-day query is needed at all.
3. The query is a windowed mean, which the daily batch already runs per day inside a single program. Keeping the buckets instead of reducing them to min, max and average is a small change to proven code. The zone option that costs the pushdown is only needed for buckets of a day or more, so a 15-minute window does not hit that problem either.

### The shape belongs to the term, not to a dependency

The shape is not the shape of a raw sensor. Reading it as one is the error this section exists to prevent.

A finance sensor is a sum of terms, and a term is one energy quantity times one price. `house_costs_pv` has one term, the house consumption that did not come from the grid, at the feed-in price. `battery_savings` has two, one per price type. `grid_energy_costs` after [A8](02-consumer-tariffs.md) has one per consumer, plus the remainder. The term is what [`price_inputs`](02-consumer-tariffs.md#price-inputs) names.

Take the shape of the term, not of each dependency it is built from. The difference is not cosmetic. Six sensors clamp their term at zero, and a clamp does not survive being taken apart:

```
Σ max(house_w − house_grid_w, 0)  >  max(Σ house − Σ house_grid, 0)
```

The two sides differ whenever the shapes cross inside the day. They do cross, because the Power Splitter averages them separately. Shaping each dependency on its own therefore breaks the invariant above. A time-of-use tariff with the same amount in every slot then stops returning what `fixed` returned. Build the clamped term per window first, then normalize it, then scale it to the stored daily value of that term. One shape per term, so `battery_savings` needs two and the rest need one.

### A term with no shape

The shape can add up to zero while the daily value does not. `SummaryCorrector` scales a grid share against a target the raw data never had. Normalizing then divides by zero, which yields `NaN` rather than an error. The summary column accepts `NaN`, because it is a float. Every sum above that day is then `NaN`, and nothing reports it.

If the shape adds up to zero, spread the daily value evenly over the windows that have data. The cost is then the daily value at the mean price of the day, which is all the data supports.

The whole approach has one trade-off. A mean is sample-weighted, not time-weighted. The same decision was taken for the chart series. It distorts the shape if the sampling density varies over the day. With a constant collector interval it does not. Make sure that this holds against real data before you rely on it.

Derive the number of windows from the timeframe, never from a constant. A DST day has 23 or 25 hours, and 92 or 100 quarter hours.

## Two arithmetic traps

**Never average the price over a window coarser than the consumption.** The cost of an hour is the sum of four quarter-hour products. It is not the hourly energy times the hourly mean price. The two differ exactly when consumption follows the price, which is the entire purpose of a dynamic tariff. The error is not random. It is a systematic discount on load that was shifted into the cheap hours. Multiply at the price resolution, then sum.

**Mind the timestamp.** The collector stamps each point at the start of its interval, and the price is valid forward from there until the next point. A windowed aggregate is right-aligned by default. A window boundary that does not match the price grid therefore moves a price into the wrong interval. Align the windows to the price grid, and carry a price forward rather than interpolating between two.

## Query cost

- **Fixed** costs nothing extra. The daily integral is already in the batch, and the weights cancel out. The multiplication is pure Ruby.
- **Time-of-use and dynamic** need the shape query. That is one windowed mean per day and sensor, inside the same program the batch already sends. It is one query per chunk of days, not one per day and certainly not one per slot.
- **Dynamic** additionally needs the price series, one query per chunk for both price sensors together.

Do not implement this with one query per day or per slot. A five-year rebuild with three slots per day would issue about 5,500 extra queries. The windowed batch is a requirement of these features, not an optimization for later. That is why it is a step of its own.

### What the shape query actually costs

The number of queries is not the whole cost, and it is the part that is already solved. The other part is the number of rows.

The daily batch reduces every window to three numbers inside InfluxDB, so one sensor and one day return a single row. The shape query is the same pipeline without that reduction, so one sensor and one day return one row per window. At quarter hours and a chunk of seven days, that is a hundredfold increase per sensor.

Two rules follow, and B1 has to prove them:

1. **Window only the sensors a finance sensor is made of.** That is the grid pair, `inverter_power`, the battery pair, every consumer that a cost sensor prices, and the `_grid` share of each of them. It is not every sensor the summary sums, and it is not the ones that carry only min, max or average.

   The count is not a constant, and the custom consumers dominate it. Thirteen power sensors with no custom consumer configured, 53 with all 20, because each one brings a pair. At 96 windows over seven days that is between 9,000 and 36,000 rows in one response. Take the upper figure into the benchmark, not the lower one. An installation with 20 custom consumers is a real configuration, and it is the case the whole feature has to survive.

2. **Benchmark the parse, not only the query.** The InfluxDB time is the part the pushdown argument is about. The rest of the cost is the response, and the Ruby that turns it into arrays. That part grows with the row count no matter how fast InfluxDB answers.

#### Reuse the per-day stream where there is one

The batch already builds a per-day stream of five-minute means and unions three reductions of it. Where that stream exists, the shape is a fourth branch of it rather than a second program.

The shape is then a mean of five-minute means rather than a mean of the raw samples. That is acceptable and arguably better. The five-minute step already removes the sampling density of the collector, and only the relative distribution is used. State it where the query is built, so nobody later "fixes" it into a raw-sample query.

**That stream covers only part of the sensors this needs.** It is built for the sensors that declare min, max or average. A declaration of `sum` alone keeps a sensor out of it. Read the declarations rather than the sensor category, because the split does not follow the category:

| In the stream (`sum max`)                                                                                                                                           | Not in it (`sum` only)                                |
| ------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ----------------------------------------------------- |
| `grid_import_power`, `grid_export_power`, `house_power`, `heatpump_power`, `wallbox_power`, `inverter_power`, `battery_charging_power`, `battery_discharging_power` | every `_grid` share, and **`custom_power_XX` itself** |

Two traps sit in that table. The battery pair is covered, unlike its grid shares. And `custom_power_XX` is a base consumer sensor, not a Power Splitter sensor, yet it declares a sum alone and is missing anyway. With 20 custom consumers the uncovered group is 40 sensors of the roughly 53. It is the larger half, not a remainder.

So B1 hangs its shape stream into whichever per-day program already reads a sensor, and builds one for the rest. Do not plan on a single insertion point, and do not derive the two groups from what a sensor is.

### The tariff sets the window

The window is a parameter of the query, not a constant, and the tariff decides it:

| Mode          | Window     | Why                                                            |
| ------------- | ---------- | -------------------------------------------------------------- |
| `fixed`       | no query   | the weights cancel out                                         |
| `time_of_use` | one hour   | §14a module 3 slots start on the hour, so an hour is exact     |
| `dynamic`     | 15 minutes | the day-ahead market and `tibber-collector` are quarter-hourly |

A time-of-use day therefore costs a quarter of the rows a dynamic one does, and it is not an approximation. A finer window returns the same number from four times the data. Only spot prices pay the quarter hour.

The hourly window is exact only because a slot cannot start between two hours. That is [a validation on the slots](#data-model), not a property of the world. Whoever relaxes that validation has to widen this window in the same commit.

Do not run dynamic mode on an hourly window to save that. It would force the price to be averaged over the hour. That is the first of the two arithmetic traps above, and it removes exactly the load shifting a dynamic tariff is bought for.

### The current day is the hot path, not the rebuild

The summarizer skips the batch for a single day, and a summary of today goes stale after minutes. So the day, month and year views rebuild it while the user watches. Today is therefore rebuilt far more often than any past day, always alone, and always without the batch.

For these modes that means one shape query plus one price query per rebuild of today. Both sit outside the batch, and both are uncacheable, because today is still being written. Measure that path on its own. Every page view feels a rebuild of today that gets slower, while a slower five-year rebuild is felt once.

**Cache the price series per finished day.** The spot prices of a past day never change again, so the vector is immutable once the day is over. The InfluxDB layer already caches per query, which covers repeated rebuilds for free. Exclude today, whose prices are still being written.

## The sub-day views

For periods shorter than a day the cost is not read from a summary. It is calculated in Ruby. That is the hourly totals and the chart points. Both go through `Influx::FinanceCalculation`, so all three modes are implemented once, in that one module.

It resolves one price per type for the whole query today, and it has to become a lookup per consumer. Beyond that the two callers need different work, because only one of them has data points at all.

### The chart series has points

It renders far below the price interval: five minutes, and thirty seconds for a one-hour timeframe. So the windows of the chart and the windows of the price do not line up. Resample the price series to the chart interval and carry each price forward, or most points get no price at all. Match by timestamp rather than by index, and treat a missing price as "no value", never as zero.

### The hourly totals have none

`Influx::Total` answers a timeframe of 1 to 99 hours with **one** number per sensor, not a series. There is no data point to hang a price on, so "a lookup per data point" has nothing to look up.

That breaks both sub-day modes, and neither is an edge case:

- **Time-of-use.** A timeframe of a few hours already spans two slots, and a day spans all of them. The entry carries no single amount, so the current code has nothing to read.
- **Dynamic.** One hour holds four quarter-hourly prices. Taking one of them, or their mean, is the first of the [two arithmetic traps](#two-arithmetic-traps). It discounts exactly the load that was shifted.

Watch the existing lookup while you change it. For an hourly timeframe `Timeframe#date` is `Time.current`, so the price is the one valid **now**, not the one valid during the window. A `fixed` tariff that changed inside a 99-hour window is already priced with the newer amount. That is tolerable for a rate that changes once a year. It is not tolerable for one that changes every 15 minutes.

So this path needs the same structure as the summary step. Split the timeframe at the price boundaries, take one energy per window, multiply each by the price of its own window, and sum. The window count is small here, because the timeframe is at most 99 hours rather than five years. It therefore needs no batch and no B1. It does need to be built, in both C1 and C2, and it is the part of those steps most easily mistaken for done.

## Missing data

If the price data for a dynamic day is missing, the cost is `nil` and no summary value is written. The summarizer even removes a cost row that existed before, so the per-field part of this already works.

What does not work is the retry. The staleness rule asks whether the **day** is fresh, not whether a field is there. A day written without its costs is therefore fresh and never comes back. The SQL path then sums the rows that exist, and a month under-reports silently instead of being obviously wrong.

**Do not solve that by skipping the write.** A summary is written or not written as a whole. A day held back for a missing price also loses its energy, and a month or year view loses the kWh of that day as well. For the current day it is worse. The summary of today is what the day view reads, so a price outage empties the dashboard of a day whose energy data is perfectly good.

Write the day, omit the cost fields, and make the day eligible for a rebuild until its prices arrive. That needs a per-day marker of its own, because the freshness rule cannot express it. The marker is a timestamp on the summary that says since when a cost was omitted. It is cleared when the day is written complete.

**The marker needs a bound**, because no collector backfills a price series. Without one, a one-week outage produces seven days that are rebuilt on every page view and never succeed. So the grace period is a bound on the marker, and it needs no job to enforce it. A day counts as stale while the marker is set and younger than a week. After that the day stops asking to be rebuilt, while the marker keeps saying why it is incomplete. That is what the UI reads.

**Two places ask whether a day is stale, and both have to learn the marker.** One is the SQL statement that lists the days to build. The summarizer then asks the same question again in Ruby, and drops every day that answers no. A marker that reaches only the SQL statement changes nothing. The day is listed, handed to the chunk, and thrown out again before a single query runs.

The marker belongs to the day, not to a sensor, because a missing price series affects every cost of that day at once.

Do not fall back to the last known price. That invents a number which looks correct and cannot be told apart from a measured one.

## Steps

Blocks B and C in the [roadmap](roadmap.md#block-b--influxdb-infrastructure). The windowed batch (B1) is built and benchmarked on its own, before either mode. Then time-of-use (C1), which needs no collector, no new sensors and no price series. Then dynamic (C2), which covers spot prices and direct marketing in one, because the path does not care which tariff it reads.

This is the first place where the InfluxDB path changes at all. `#calculate_with_prices` is extended here rather than replaced.

## What the MCP server exposes

Two tools answer questions about prices, and they answer different ones. `get_prices` reports the tariff that was agreed. The price sensors report the curve that was measured. Say that in both descriptions, because the words for the two are almost the same.

**The price sensors are listed.** `electricity_price` and `feed_in_price` appear in `list_sensors` like any other sensor. So `get_series` can answer "when was electricity cheapest today". Their description names the other tool for tariff questions, and says that the unit is averaged and never summed.

### They are the first sensors with no summary behind them

`McpServer::SupportedTools` derives the advertised tools from the sensor. Work it through for a price sensor and four of the five letters come out right on their own. It is live, and it has a curve. `r` drops out because `rankable?` asks for a stored field or a SQL calculation, and a price sensor has neither.

`t` is the one that does not. The flag is true as soon as the sensor allows any aggregation, and the average has to be allowed for `get_series` to work at all. But `get_totals` picks its backend from the timeframe. Hours go to InfluxDB, and a day or longer goes to SQL over `summary_values`. A sensor that is never stored has no row there, so the SQL path returns null for every timeframe from a day upwards. The matrix would advertise `t` while the tool answers nothing. That is the exact failure the matrix exists to prevent.

Every sensor before this one was either stored or derived from stored sensors. No sensor has ever had a live curve and no summary at the same time. Two answers exist. Either the SQL path refuses a sensor it cannot store, so `t` becomes a per-timeframe answer, or the price sensors are declared so that `t` is never claimed. The first one changes a rule for every sensor, and the second one hides a curve the hourly path can serve. So this is a [stop point](roadmap.md#where-a-step-stops) of C2, to be settled rather than discovered from a null. Whichever way it goes, `bin/llm-test` runs afterwards, because the letters are what a model reads before it calls anything.

**`get_prices` reports no single amount where none exists.** The mode says why, and it has to. An empty amount already means something else there. The tool reports one today when the history begins after the requested date, which means "no tariff at all". Without the mode in the same object, a model reads both cases as "no price is configured". So the mode is not optional metadata. It is what disambiguates the empty amount.

Sorting needs a decision at the same time. Sorting the history by amount orders it by something a time-of-use or dynamic entry does not have. Sort those entries last, whatever the direction, and say so in one clause of the description. A time-of-use entry carries its slots with it, so the caller sees the amounts without a second call. A dynamic entry carries nothing but the mode, and the description points at the series of the price sensor. Do not invent a number for it. The field promises the tariff of a date, and neither the amount at the moment of the call nor a daily average is that.

Both of these are tool descriptions, and those are load-bearing for the LLM tests. Run `bin/llm-test` after changing them, and `--ablate` before adding a sentence.

## The daily boundary

Both modes need sub-day data for a day that has already been summarized. That is fine for the summary step, which queries InfluxDB anyway. But it rules out ever computing a finance sensor from the stored daily sums alone.

## Every amount is gross

Every amount in SOLECTRUS includes taxes and levies. That is true of a price typed into Settings, and it is true of what `tibber-collector` writes, which is the gross total of the Tibber API. So the two agree today. It is nowhere written down, which is the problem. A collector that reports the bare spot price understates every cost by about a third, and nothing looks wrong.

State it in `docs/sensor-reference.md` and in the description of the price sensors. Do not model it. A net amount and a tax rate would touch the price form, the validations and every existing row, for a case that does not exist yet. An installation that wants to work in net amounts enters net amounts and does not use a gross collector.
