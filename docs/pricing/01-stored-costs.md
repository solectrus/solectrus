# Stored Costs

Move the money from "computed when a page is rendered" to "computed once per day and stored". Nothing about the tariff changes. This is plumbing, and it is the prerequisite for [03-sub-day-prices.md](03-sub-day-prices.md).

Prerequisite reading: [current-state.md](current-state.md).

**Starts after the base fee has landed.** This is written against the `prices` table and the sensor split that the monthly base fee introduces. Doing the two at once means converting `grid_costs` to a stored sensor while it is still being split into `grid_energy_costs` and `grid_base_fee`. That is two irreversible changes in one step.

Issue: #5340.

## Why

A day has exactly one price today, so a cost can be computed at render time. The query joins `prices` onto the daily energy sums. Time-of-use and dynamic pricing end that, because a daily sum cannot say how much energy fell into the expensive hours. The multiplication has to happen while sub-day data is still reachable. That means once per day, in `SummaryBuilder`.

Everything the SQL path does afterwards gets simpler. `grid_costs` becomes a stored field that is summed like `house_power`, and the price join disappears.

## What gets stored

Every finance sensor that multiplies energy by a price becomes `stored: [:sum]`, one record per day.

| Sensor                 | Price       | From                                                                                       |
| ---------------------- | ----------- | ------------------------------------------------------------------------------------------ |
| `grid_energy_costs`    | electricity | `grid_import_power`                                                                        |
| `grid_base_fee`        | —           | the tariff and the calendar, no energy at all                                              |
| `grid_revenue`         | feed_in     | `grid_export_power`                                                                        |
| `house_costs_grid`     | electricity | `house_power_grid`                                                                         |
| `house_costs_pv`       | feed_in     | `house_power` − `house_power_grid`                                                         |
| `heatpump_costs_grid`  | electricity | `heatpump_power_grid`                                                                      |
| `heatpump_costs_pv`    | feed_in     | `heatpump_power` − `heatpump_power_grid`                                                   |
| `wallbox_costs_grid`   | electricity | `wallbox_power_grid`                                                                       |
| `wallbox_costs_pv`     | feed_in     | `wallbox_power` − `wallbox_power_grid`                                                     |
| `custom_XX_costs_grid` | electricity | `custom_power_XX_grid`, XX = 01–20                                                         |
| `custom_XX_costs_pv`   | feed_in     | `custom_power_XX` − `custom_power_XX_grid`                                                 |
| `battery_savings`      | both        | `battery_discharging_power`, `battery_charging_power`, and their `_grid` shares if present |
| `opportunity_costs`    | feed_in     | `inverter_power` − `grid_export_power`                                                     |
| `traditional_costs`    | electricity | the dependencies of `total_consumption`, priced per dependency                             |

These stay computed, because they are derived from the stored ones and need no price:

| Sensor                       | Calculation                                   |
| ---------------------------- | --------------------------------------------- |
| `grid_costs`                 | `grid_energy_costs` + `grid_base_fee`         |
| `house_costs`                | `house_costs_grid` + `house_costs_pv`         |
| `heatpump_costs`             | `heatpump_costs_grid` + `heatpump_costs_pv`   |
| `wallbox_costs`              | `wallbox_costs_grid` + `wallbox_costs_pv`     |
| `custom_XX_costs`            | `custom_XX_costs_grid` + `custom_XX_costs_pv` |
| `grid_balance`               | `grid_revenue` − `grid_costs`                 |
| `solar_price`                | `grid_costs` − `grid_revenue`                 |
| `savings`                    | `traditional_costs` − `solar_price`           |
| `house_without_custom_costs` | proportional from `house_costs`               |
| `total_costs`                | `grid_costs` + `opportunity_costs`            |

`grid_base_fee` is the odd one. It needs no energy and no InfluxDB, only the tariff and the length of the month, so it can stay computed. It cannot stay computed anyway. Leaving it computed keeps the price join alive for the one sensor that would still need it, and that defeats the point. Store it like the rest.

### Size

`summary_values.field` is a PostgreSQL enum, not a free string, so every new field is a migration. Counting all 20 custom consumers that is 52 new values, 40 of them the `custom_XX_*` pair. The count does not depend on how many a concrete installation uses.

**A field carries the name of its sensor.** Every value in the enum does that today, and nothing here is a reason to break it. So the 52 names are the first column of the table above, and there is nothing left to invent.

**Enum values cannot be removed.** That is a rule about a database a user has, not about the branch this is built on. A development database can be reset, so a name stays correctable for as long as the work sits on the [working branch](roadmap.md#where-the-work-happens). The names have to be right before the release that ships them, not before the first commit.

The row count is not a problem. A typical setup adds roughly 21 rows per day, about 38,000 over five years. The table already carries the power sensors and is keyed by date, aggregation and field. No new index.

The stored value is a float while prices are decimals. The multiplication happens in Ruby and is stored at the precision the power sums already have. Round once at the formatting boundary, never per day.

## Order of operations

`SummaryBuilder` needs a third collection step, because a finance sensor passes neither of the existing filters (see [current-state.md](current-state.md#the-details-that-break-things)).

**That step must run last, after cleanup and after the value corrections.** This is the easiest correctness mistake in the whole folder, because the current order looks harmless. Two later stages rewrite the very numbers a cost is made of. An all-day zero becomes `nil`, and `SummaryCorrector` rescales every grid share.

Today the order is right by accident. Costs are computed later, from values that were already corrected. Once costs are stored, the order is explicit and needs a spec to defend it. The invariant to state:

> A stored cost is always the price applied to the stored energy, never to the energy before correction.

A finance sensor also has to stay out of the sensor list that goes to `Influx::DailyBatch`, because it has no InfluxDB field to query. Nothing has to be done for it. That list keeps only configured watt sensors, and a finance sensor is neither. Treat it as an invariant to protect rather than as a task, and do not relax those two filters.

### The sensor does the multiplication, not the step

The step collects and stores. What a cost is stays in the definition, in `#calculate_with_prices` and `#with_base_fee`.

Those two already do the whole job. `Influx::Total` calls them with the energy of a timeframe and the price of that timeframe. The summary step calls them with the energy of a day and the price of that day. The values have the same shape, so the step passes the corrected daily sums, and the result is the number to store.

That settles the case of `traditional_costs`. It looks like it cannot say what to price, because its dependency list is a Proc. It does not have to say it. The list is evaluated when it is read, and the sensor prices its own dependencies, the way it does for the hourly view today.

Two things follow:

1. The stored cost and the hourly cost cannot drift apart, because there is one calculation and not two.
2. Block A needs no new declaration on a definition at all. A sensor is converted by its `aggregations` line and its `#sql_calculation`, nothing else.

A declaration is needed later, when a price stops being one number per type. That is per consumer in [02-consumer-tariffs.md](02-consumer-tariffs.md#price-inputs), and per time slot in [03-sub-day-prices.md](03-sub-day-prices.md). `#calculate_with_prices` stays the calculation in both.

It does not stay unchanged, though, and A8 is where that bill falls due. Every implementation reads `prices[:electricity]` or `prices[:feed_in]` today. Once two dependencies of one sensor can sit on different tariffs, the hash is keyed by term rather than by type. Every body that reads it is then rewritten. `traditional_costs` changes the most, because it multiplies one rate by a sum today and has to price each part on its own. Block A needs no new declaration up to A7. A8 needs one, and it reaches into every definition that implements the method. That is thirteen today, plus whatever A1 adds.

## The SQL path

`#sql_calculation` does **not** disappear. It is pointed at the stored column.

Removing it is the obvious move and it breaks the application. `Sensor::Config#exists?` uses it as the only evidence that a finance sensor exists at all. Delete the method and `grid_costs` vanishes from the registry, the menu, the summary and every query.

Pointing it at the stored column is also the smaller change. Once the sensor is stored it resolves to a field of its own. The daily CTE then builds that column without being told, and the meta-aggregation wraps it like any other. Do not coalesce it to zero. A day without a value must stay NULL, or an ungrouped total counts a missing day as zero cost.

### A day without energy is NULL, not zero

That is a deliberate change of behavior, and it is the one number that does not reproduce. The SQL expressions today coalesce a missing energy sum to zero, so a day with no energy row costs 0. A stored cost writes no row for that day at all.

A `SUM` over a period is the same number either way. Two other readers are not:

- The meta-aggregation `min`. `grid_costs` offers it. The cheapest day of a period is 0 today, and afterwards it is the cheapest **reported** day.
- The top-10 ranking, for the same reason.

The new number is the correct one. A day the meter never reported did not cost nothing. Expect the difference in the correctness check below, and do not try to remove it by coalescing.

#### Three sensors do not follow that rule yet

`#calculate_with_prices` is not consistent about it. `house_costs_pv` returns `nil` when a dependency is missing. `opportunity_costs`, `battery_savings` and `traditional_costs` treat theirs as zero and return a number as long as a price exists. Stored, that writes a zero on every day the meter never reported. `min` and the ranking then mean something different per sensor.

Make them agree in [A6](roadmap.md#a6--the-awkward-ones), where the three convert. The rule is `nil` when no dependency has a value. A genuine zero from a sensor that did report stays zero.

### But a composed sensor must tolerate a missing part

This is the other half of the same rule. Getting only the first half right produces a silent, large error.

Several sensors splice the SQL of their parts with `+` or `-`. `grid_costs` is built from its two halves, `solar_price` from `grid_costs` and `grid_revenue`, and `savings` and `total_costs` from theirs. Today every spliced part coalesces to a number, so it is never NULL.

Once the parts are stored columns they are NULL on a day that has no such row. In SQL a NULL in a sum makes the whole row NULL. Two ordinary situations produce it:

- A day with grid import and no export. `grid_revenue` has no row, so `solar_price` and `savings` are NULL for that day and drop out of every sum above it.
- A tariff with no monthly amount. `grid_base_fee` then has no row at all, so `grid_costs` is NULL on **every** day.

**The first of those two arrives with the very first stored sensor.** `grid_revenue` is converted in [A3](roadmap.md#a3--first-stored-sensor-grid_revenue). It is spliced by `solar_price`, which is spliced by `savings`. From that commit on, every day without feed-in is missing from the savings total, the savings ranking and the amortization. The amortization reads `savings` out of `summary_values`. A winter with little export loses most of its days, and no page says so.

So the coalesce helper is part of A3, not of the step where the second part becomes stored. A4 is where the second situation is added, not where the rule starts.

A composed expression coalesces each part and stays NULL only when every part is missing. The Ruby side of `grid_costs` already does exactly that, and it is the pattern to copy. The leaf sensor keeps its NULL, and the composition does not inherit it.

Put it into one helper on `FinanceBase` and let every composed sensor splice through it. The compositions nest three deep, from `grid_costs` through `solar_price` into `savings`. Writing the rule by hand at each level is where the one forgotten coalesce will be.

Write a spec per composed sensor with one part missing. This error does not raise and does not look wrong on a chart. It removes days.

The splicing in `savings` and `solar_price` keeps working untouched. It asks its parts for their SQL, and those parts now name their own stored column.

Removing the join is itself a speed-up. The current path builds a CTE with a window function and adds up to two joins to every daily row of every money query. Afterwards a year of `grid_costs` is one sum over an indexed field. If a benchmark shows this getting slower, something is wrong.

## What stays

Deleting `#required_prices` and `#calculate_with_prices` along with the price CTE looks right. It would break every hourly view and every chart.

Both have a second caller that has nothing to do with SQL. `Influx::FinanceCalculation` reads `#required_prices` to decide which prices a query needs, and it calls `#calculate_with_prices` to turn power into money. It serves the hourly totals and the chart series, which answer timeframes shorter than a day. Those views have no daily row to read, so they keep calculating money in Ruby no matter what the summary stores.

The two are not the same shape, which matters later and not here. The chart gets one call per point, and the hourly totals get one call for the whole timeframe. A fixed price does not care. A sub-day price does, and [03-sub-day-prices.md](03-sub-day-prices.md#the-hourly-totals-have-none) is where that is worked out.

So this change touches the SQL path only:

| Method                   | SQL path                                                  | InfluxDB path |
| ------------------------ | --------------------------------------------------------- | ------------- |
| `#sql_calculation`       | names its own stored column instead of a price expression | not used      |
| `#required_prices`       | no longer read by the CTE builders                        | unchanged     |
| `#calculate_with_prices` | not used                                                  | unchanged     |

Not a single Flux query is added or altered. That is what makes the whole change PostgreSQL-only.

## It does not have to be one big step

Two properties make this splittable.

**Converted and unconverted sensors can share a query.** The registry can already resolve a sensor to the fields it is stored under: itself when it is stored, its dependencies when it is not. The ranking uses that today. The other two places that collect the dependencies of a finance sensor for a query have to ask the same question instead. Then the two kinds coexist. The price CTE is built only while some sensor still declares a price, so the old path stays alive for whatever has not been converted.

**One branch changes its mind when a sensor becomes stored.** The heatmap decides between a calculated and a stored-column path on "calculated and not stored". A converted finance sensor stops being the first and takes the stored-column path, which is the correct one. Cover the heatmap of a money sensor with a spec, and fix the comment there that names finance sensors as its example of the calculated path.

The similar-looking branch in `Sql::Total` is not the same test and does not change. Leave it alone.

Convert `grid_energy_costs` and `grid_revenue` first. Make sure that the numbers are right. Then take the rest in groups.

### Backfill instead of rebuild

**No summary wipe, and no InfluxDB.** In fixed mode a daily cost is a pure function of two things that are already in PostgreSQL: the daily energy in `summary_values` and the tariff in `prices`. So one statement fills the history. It joins the daily energy rows onto the tariff timeline and upserts the product, over a date range. It is the expression the current CTE already computes, written as an insert instead of a select.

The same statement serves two purposes, which is why it is worth getting right once. It does the one-time backfill over the whole history, and it does the recalculation of a date range after a price edit. Only the range differs.

#### An insert cannot remove a row

An upsert writes and corrects. It never deletes, and three ordinary edits need a deletion:

- A price row is deleted, and no other row covers the days it covered.
- The oldest start date moves forward in time, so the days before it have no price any more.
- The monthly amount is cleared, so `grid_base_fee` has nothing to write.

Each of them leaves a cost row that looks valid and rests on a tariff that is gone. So the recalculation is a delete followed by the insert, not the insert alone. A day whose price is gone then has no cost row, and that is what a day without a tariff means.

#### The range is wider than the changed row

"From the start date to the next entry" is the range of a row that is created, and of a row whose amount is edited. It is too narrow for the other two cases, because the neighbors change their validity as well. A deleted row hands its days to the previous one. A moved start date affects the old window and the new one together.

So compute the range from the record before and after the change, and take the union. Recalculating too much is cheap here. One statement over five years of daily rows is still one statement.

It reproduces the old numbers exactly, because it is the old formula. It runs in seconds instead of re-querying 1,800 days from InfluxDB. It also leaves the `summaries` rows untouched, so no day becomes stale.

`grid_base_fee` is the exception. It backfills from the calendar rather than from an energy row. The fee falls due whether the meter reported or not, so it needs a row for every day in range. Drive that calendar from the `summaries` table. A value row can only exist for a day that has a summary, and a day nobody ever summarized carries no fee until somebody does. That is consistent with the rest of the table, where a day without a summary has no values at all.

#### It is also the first value that is not a measurement

Every row in `summary_values` came from a meter so far. `grid_base_fee` is the first that comes from a calendar, and one query in the application reads the table as if that cannot happen.

`MeasuredRange#installation_date` takes the later of the configured installation date and `SummaryValue.minimum(:date)`, over the whole table and every field. Its own comment says why. It clamps to the first day with measured data, so a forgotten `INSTALLATION_DATE` cannot pretend the system has been running since 2020. A fee row satisfies that query and measures nothing.

A summary can exist for a day that has no value rows at all. The summarizer writes the summary and then deletes the values that came back empty. Open a year view for a year before the meter existed, and those summaries are created. After A4 each of them carries a fee. The minimum then moves back to the first of them, and `installation_date` moves with it. The amortization divides the measured savings over more days than were ever measured. The savings per day and per year fall, the projection follows, and nothing in the data changed.

So A4 narrows that query to a field that really is measured. Do not fix it by keeping the fee off those days instead. A month the user paid for is a month the user paid for, and the fee row is right.

#### What the backfill buys

It removes the version bump, and with it most of the risk. The enum values are still permanent, but no data is destroyed. The backfill only adds rows, and every energy row stays as it was. What it does not buy is a downgrade path, see "Rollback is not supported" below. Keep the version bump in `SummaryInvalidator` in reserve, for the case where the backfill and the old path disagree.

A full wipe would mean re-querying every day since the installation date. That is about 1,800 day-equivalents for five years, spread over whatever timeframes the user opens. It also assumes the raw data is still there, which holds, because SOLECTRUS keeps InfluxDB data indefinitely. The wipe comes back in [03-sub-day-prices.md](03-sub-day-prices.md), where a cost genuinely depends on data that only InfluxDB has. By then the mechanism is proven.

## A price change must not rebuild from InfluxDB

When a price is created, edited or deleted, the costs of the affected days are wrong and have to be redone. Deleting summaries and rebuilding them is unnecessary work of a different order. Correcting a tariff that has been in place for five years would re-query 1,800 days for nothing.

Two tiers:

1. The changed entry is `fixed` and replaces a `fixed` one. Recalculate the affected cost rows from the daily sums already in `summary_values`. No InfluxDB, no summary deletion, one pass over the date range. This is the backfill above, restricted to the range the change affects.
2. Anything else, which means a mode that needs sub-day data. Delete the summaries and let them rebuild.

Tier 1 is not the optimization that tier 2 gets later. It is the only version that exists in block A, because no other mode is there yet. It also costs nothing extra, because the statement is already written for the backfill. Tier 2 arrives with the first sub-day mode, which is the first thing that can need it.

Tier 1 covers the common case in the long run as well, because most users never leave fixed mode. Keep the invariant that a summary is deleted and rebuilt as a whole. Tier 1 does not delete a summary. It recomputes derived rows of a summary that stays valid. Name the two operations differently in the code, so they do not get confused.

### Where the recalculation runs

Tier 1 runs inline, when the price is saved. It is two statements over an indexed table.

Do not assume that stays comfortable. Editing the oldest entry covers the whole history. By [A5](roadmap.md#a5--the-consumer-costs) that is about 21 cost fields per day, so five years is tens of thousands of rows deleted and written again inside the request that saves the form. Measure it on a five-year database while converting the first group, and move tier 1 into a job if it does not stay quick. The statement is the same either way. Only the caller moves.

**This is a [stop point](roadmap.md#where-a-step-stops).** No development system carries five years of summaries, so write them rather than summarize them. The rows are known and few, roughly 38,000 over five years, and the measurement needs their shape rather than real energy. Then time the edit of the oldest entry, which is the worst case there is, and present the number. Whether that number is acceptable inside a form submit is a decision and not a measurement.

#### What happens when it fails

Answer this before choosing where it runs, because the two answers differ.

Today a price edit cannot leave anything inconsistent. The costs are computed at render time, so the tariff is the only thing that has to be saved. From A3 on, saving the tariff and correcting the costs are two operations, and the second one can fail. A timeout on a five-year range, a deploy in the middle of it, a job that never runs. The tariff is then new and the numbers behind it are old, and nothing on any page says so.

Run the recalculation inside the transaction that saves the price, and the pair is atomic. The edit fails as a whole and the user sees an error, which is the honest outcome. That is the reason to keep it inline for as long as it stays fast, and it is a stronger reason than speed.

A job cannot have that. So a job needs the fallback instead. When the recalculation fails, mark the affected summaries stale and report the error. The days are then rebuilt from InfluxDB, which is the expensive path this whole section avoids. That is the right price for a failure. Do not leave the failure silent, which is what a bare job does.

#### Two edits the correction never sees

The recalculation hangs off the act of saving a price. Two ordinary things happen beside that act, and neither triggers it.

**A price changed without the model.** A console session, a seed file or a plain SQL statement can write the `prices` table directly. The tariff is then new and every cost behind it is old, which is the same end state as a failed recalculation, without the error that reports one. Do not guard it. The repair is the backfill over the affected range, and it is the statement that is already written. Name it where the backfill lives, so that whoever finds a wrong number reaches for it instead of wiping the summaries.

**A summary written while the price is saved.** Tier 1 deletes and inserts the cost rows of a range. A summary run for a day in that range can already be in flight, holding the tariff it read before the change, and its write can land after the correction. That one day then keeps a cost from a tariff that is gone, and nothing says so.

The window is one summary run wide and it needs a price edit inside it. So the price of a guard is higher than the price of the error. Do not lock. The next price edit corrects the day, and so does a backfill over its range. It is written here because a wrong day with no explanation is worse than a wrong day with one.

#### Tier 2 runs in the background

Tier 2 must not run inline at all. Deleting a range of summaries makes every one of those days stale, and the next page view rebuilds them from InfluxDB. Doing that in the request that saves the price turns a form submit into a rebuild of the history. So tier 2 deletes the summaries and returns. The existing staleness mechanism does the rest, in the background, day by day, as the views ask for them.

#### The arithmetic exists twice

Each group of converted sensors extends tier 1 by its own fields. This is the one place where the arithmetic of a sensor is written a second time, in SQL rather than in Ruby.

That duplication has a failure mode of its own, and it is quiet. A day written by the summary step uses the Ruby calculation. The same day recomputed after a price edit uses the SQL one. If the two differ, editing an unrelated tariff changes historic numbers that nobody touched, and nothing reports it.

So every converted sensor needs a spec that the two agree. Build a day the normal way, run the recalculation over that date, and compare the value with itself. It is a cheap spec, and it is the only thing that keeps the second expression honest.

#### The cache

A targeted recalculation does not clear the Rails cache, and for tier 1 that is harmless. No SQL money query is cached. The amortization carries the price table in its cache key, the InfluxDB layer caches raw rows rather than money, and there is no fragment caching in the views. Whoever adds a cache over a stored cost has to invalidate it here.

Tier 2 turns that same cache key into a problem, so [C1](roadmap.md#c1--time-of-use) has to answer it. The amortization reads the `savings` sensor out of `summary_values`, and its key moves the moment the price is saved. The summaries behind it are deleted at that moment and only rebuilt over the following page views. So the amortization caches a figure computed from a gap, under a key that says it is current, until the next price edit. Two answers exist. Tier 2 rebuilds its range before it returns, or the amortization stops caching while days are missing. They differ in what a user sees after a price edit, so this is a [stop point](roadmap.md#where-a-step-stops) of C1 and not a detail of it.

## Negative values

Spot prices can be negative. With direct marketing a feed-in price can be negative too, so a daily total can be negative. Nothing must clamp it to zero.

The existing range clamp is not what guards that. It runs during the cleanup stage, which is over before the new collection step starts, so a finance sensor never passes through it. The rule belongs to the new step. It must not clamp, and it must not grow a range check of its own later. Write the spec against the step, or it defends a line the value never reaches.

## Correctness check

The stored path must reproduce the old numbers. Test it for a fixed price, and for a price that changes inside the queried period. The figures to compare are the finance totals for a day, a month, a year and a top-10 ranking.

The totals agree by construction. Both multiply the same stored daily sum by the price of that day. Only the point of the multiplication moves.

Two differences are expected, and a comparison that does not show them is the suspicious one:

- A period that contains a day without energy data has a different `min` and a different ranking, for the reason above. The totals stay equal.
- A period whose days all carry energy data must match everywhere.

Compare with a tolerance, not for exact equality. Both paths multiply once per day, so the granularity is the same. The arithmetic is not. The old path multiplies in PostgreSQL `numeric`, which is exact decimal. The stored path multiplies in Ruby `Float` and keeps a float. Five years of those floats add up with a representation error the old sum never had. On a five-year total the difference is far below one cent, but it is not zero. A difference in the cent range or above is a bug.

### Make it a spec, not a session

"Record the totals, then compare" reads as something a person does once. Write it as a spec instead. It then keeps its value after the old path is gone, which is the point at which the comparison can no longer be repeated by hand.

Seed the days the comparison needs, read the four figures out of the current code, and write them into a spec as the expected values. Then convert the sensor. The spec holds what the old path answered, and every later group is measured against the same numbers rather than against a fresh reading of a path that has already moved.

Three properties belong in that seed, or the comparison agrees for the wrong reason:

1. A price that changes inside the queried period, so that the timeline is exercised rather than one amount.
2. A day without energy data, which is the one place the two paths are meant to differ.
3. A day with no export at all, because that is what the coalesce helper of A3 exists for. A period without such a day never touches it.

Nothing in this needs InfluxDB. Both figures come out of `summary_values` and `prices`, and both are PostgreSQL tables.

### A seeded day is a day somebody thought of

The spec suite proves that the arithmetic did not move. It cannot prove that the conversion left a real installation alone. A real database carries days nobody would seed: a meter fault, a corrector that moved a number a long way, a year that starts before the first reading.

So take the same four figures from a real database before the step, and compare them after it. That comparison is the acceptance of A3, and it belongs to whoever owns the data.

## Steps

Steps A2 to A7 in the [roadmap](roadmap.md#block-a--postgresql-only). The sensors convert in four groups, one commit per group. Inside a group the definitions, the CTE and the registry would otherwise disagree about where a price comes from. Between groups the application is consistent. That is the point of splitting it this way.

## Rollback is not supported

A downgrade does not destroy anything. The enum values cannot be removed and stay. The old code asks for the fields it knows, so it ignores the cost rows.

What it does not do is keep them true. The old version rebuilds a stale day without writing cost rows and without deleting them. The energy of that day changes and the cost beside it does not. After an upgrade the day looks fresh and carries a cost that no longer matches it.

Say so in the release notes rather than building for it. After a downgrade and a later upgrade, reset the summaries once. The backfill does not rest on this. It is needed for the conversion itself and for every price change, and that is what pays for it.
