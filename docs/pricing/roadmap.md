# Roadmap

The order to build this in, and why that order. The feature files say what each piece is and why it works that way. This file says when, and what ships together.

One rule shapes the list: **everything that touches only PostgreSQL comes before anything that touches InfluxDB.** That falls out of the work itself. A daily cost in fixed mode is the stored daily energy times a number. The storage change and the consumer tariffs therefore need no Flux query at all. Only sub-day prices do, and by then the storage they write into is proven.

Each step is one shippable change. No step leaves the application in a state where a page is wrong. That is a property of a step, not a plan to release it. Nothing from A2 on reaches a user before the whole roadmap is finished (see [where the work happens](#where-the-work-happens)).

## Where the work happens

Step A1 is independent of everything else here. It goes to `develop` and is released there, because the monthly base fee is a feature of its own and waits on nothing in this roadmap. The working branch takes A1 from `develop` rather than carrying it.

Every step from A2 on stays on a branch of its own until the whole roadmap is finished. `develop` is not a staging area. Power users run it, and A3 to A6 add enum values to `summary_values` that cannot be removed once a user has them in a database. Block B can still fail, and a failed benchmark is a reason to rethink block C. It is not a good moment to discover that everything before it already shipped.

Three things follow.

**Merge `develop` into the branch regularly, not at the end.** The branch lives for months against a `develop` that keeps moving. Nothing else on this list is as likely to hurt, and nothing else is as cheap to prevent. Expect `.changelog/unreleased.md` to conflict every time, because a release on `develop` empties it. The branch keeps its own lines until it returns.

**The enum names stay correctable until a release ships them.** A development database can be reset, and the branch is what keeps every database that carries these fields a development one (see [size](01-stored-costs.md#size)). That freedom ends with the release, not with the merge.

**Consolidate the migrations before the branch goes to `develop`.** Block A adds 52 enum values, and the names are expected to move while the work is open. Ship one clean set rather than a chain of corrections.

[current-state.md](current-state.md) follows the branch. It starts as a description of `develop`, and any step that changes what it describes updates it in the same commit. The first update arrives with A1, which reaches the branch as a merge from `develop` rather than as a step of its own.

## Status

This table is the only place the progress is tracked. Update it in the same commit that finishes a step, the way `.changelog/unreleased.md` is updated with a user-visible change. GitHub carries the release status through milestones, not a copy of this list.

`todo` — not started. `wip` — in progress. `done` — merged into the working branch.

| Step | What                    | Status |
| ---- | ----------------------- | ------ |
| A1   | Monthly base fee        | wip    |
| A2   | Preparation             | todo   |
| A3   | First stored sensor     | todo   |
| A4   | Grid costs and base fee | todo   |
| A5   | Consumer costs          | todo   |
| A6   | The awkward ones        | todo   |
| A7   | Retire the price join   | todo   |
| A8   | Consumer tariffs        | todo   |
| B1   | Windowed daily batch    | todo   |
| C1   | Time-of-use             | todo   |
| C2   | Dynamic prices          | todo   |

## Where a step stops

Four points need a decision that the work itself cannot supply. Each one is a measurement or a trade-off between two acceptable answers. Do the work up to that point, put the numbers or the options on the table, and wait for the decision.

1. **A3, the time an inline recalculation takes.** A price edit corrects the stored costs inside the transaction that saves it. Measure that against a five-year database, then decide whether it stays inline or moves into a job. The statement is the same either way, so only the caller is in question. See [where the recalculation runs](01-stored-costs.md#where-the-recalculation-runs).
2. **B1, the windowed batch.** Build the query and the benchmark, run it, and present the numbers. Whether block C goes ahead at all is decided from them, and the benchmark has three requirements of its own. See [B1](#b1--a-windowed-daily-batch).
3. **C1, the amortization cache.** Tier 2 deletes a range of summaries, and the amortization caches a figure computed from the gap. Two answers exist and they differ in what a user sees. See [the cache](01-stored-costs.md#the-cache).
4. **C2, the `t` flag of a price sensor.** A sensor with a live curve and no summary behind it is new, and the tool matrix has no answer for it. See [they are the first sensors with no summary behind them](03-sub-day-prices.md#they-are-the-first-sensors-with-no-summary-behind-them).

Everything else on this roadmap is decided. Where another file says "decide", it means one of these four. The exception is [04-energy-sharing.md](04-energy-sharing.md#open-questions), which carries open questions of its own and is [not a step here](#not-on-this-roadmap-energy-sharing).

---

## Block A — PostgreSQL only

The hourly and chart views keep calculating money in Ruby throughout this block. So two `FinanceBase` methods that look dead here are not. See [what stays](01-stored-costs.md#what-stays).

### A1 — The monthly base fee

Written on a branch of its own, and released through `develop` like any other feature. It is the only step here that takes that route (see [where the work happens](#where-the-work-happens)). Issue #2560.

Everything after this assumes it. The step splits `grid_costs` into `grid_energy_costs` + `grid_base_fee` and adds `amount_per_month` to `prices`. Converting a sensor to stored while it is still being split would be two irreversible changes at once. The rest of this section is what that step brings. It is summarized here because every other file in this folder builds on it. `docs/sensor-reference.md` carries the full description once the step is merged.

**A price entry gains an optional monthly amount**, valid on an electricity price alone. The column that holds the amount per kWh keeps its old name. Renaming it would break the older SOLECTRUS versions a user can roll back to, so the rename waits for a release that no longer has to be compatible with them. New code goes through the alias instead.

**The electricity tariff has two parts**, so `grid_costs` is composed from two sensors rather than calculating both itself:

```
grid_costs = grid_energy_costs + grid_base_fee
```

The fee is **not** added at display time for monthly views. That is the older design, and an easy one to fall back into. The fee is spread over the days it covers. One day carries the monthly amount divided by the length of its month. A full month adds up to exactly the monthly amount, and a partial month prorates by day. That makes the fee work for a day and a week view as well.

Each backend gets the fee in the unit its own values have. Per day for the SQL path, where one row is one day. For the whole timeframe in the hourly totals, whose values are energy. Per hour in the chart series, whose values are power.

A sensor declares its share once: none, the whole fee, or the name of a sensor whose share of the grid import scales it. Both backends read that one declaration, so a sensor cannot bill the fee in SQL and forget it in InfluxDB.

Three consequences for the rest of this folder:

- **The fee belongs to the grid connection, not to a consumer.** The model allows a monthly amount only on an electricity price. A consumer tariff (see [02-consumer-tariffs.md](02-consumer-tariffs.md)) therefore gets no fee of its own, unless somebody deliberately changes that rule.
- **`traditional_costs` carries the full fee too.** You pay it with or without PV, so it cancels out in `savings` and leaves the amortization untouched. This replaces the older idea of keeping the fee out of `savings` entirely.
- **A missing reading cancels the energy costs, but not the fee.** The grid connection costs the same if the meter stops. Only when there is neither does the value stay `nil`, so a gap in the data still reads as a gap.

### A2 — Preparation, no behavior change

A small PR that cannot break anything on its own. It is not optional, though, and calling it preparation undersells it: **A3 raises without it.**

The two places that still collect the SQL dependencies of a finance sensor ask for its storable fields instead. Today that is the same answer, because nothing is stored. From A3 on it is not. The select builder reads the `#sql_calculation` of a converted sensor, which names its own column. The CTE builder is still told to build the columns of its dependencies. The query then references a column the CTE never selected, and PostgreSQL rejects it. That is the one failure in this whole folder that is loud, and it is loud only because A2 was skipped.

Verify: the full spec suite is green and no query plan changes.

### A3 — First stored sensor: `grid_revenue`

The pilot. `grid_revenue` is the cleanest sensor in the set: one dependency, one price, no base fee, no power-splitter interaction.

1. Add the field to the enum and declare the sensor stored, with its SQL pointing at its own column
2. A new collection step in `SummaryBuilder`, running **after** the value corrections, calling the `#calculate_with_prices` of the sensor. Keep the sensor out of the list that goes to InfluxDB, and do not clamp its result
3. The coalesce helper for composed sensors, with `solar_price` and `savings` spliced through it (see [a composed sensor must tolerate a missing part](01-stored-costs.md#but-a-composed-sensor-must-tolerate-a-missing-part))
4. Backfill the history (see [01-stored-costs.md](01-stored-costs.md#backfill-instead-of-rebuild))
5. Run the same recalculation when a price is saved, over the range the change affects, in the transaction that saves the price. Measure it against a five-year database, and treat the result as a [stop point](#where-a-step-stops) (see [what happens when it fails](01-stored-costs.md#what-happens-when-it-fails))
6. Check the heatmap, which changes its path here (see [01-stored-costs.md](01-stored-costs.md#it-does-not-have-to-be-one-big-step))

Step 3 belongs here and not later. `grid_revenue` is spliced by `solar_price`, and `solar_price` by `savings`. The moment `grid_revenue` names a stored column, every day without feed-in makes both of them NULL. That day then drops out of the savings total, the savings ranking and the amortization. Storing the cleanest sensor in the set still breaks the two sensors above it, so the pilot is not as isolated as it looks.

Step 5 is not optional. Nothing invalidates a summary when a price changes today, because nothing has to. A cost is computed at render time, so it is always current. The moment the first cost is stored, that stops being true. An edited tariff then leaves wrong numbers behind, with nothing to correct them.

Its range is the union of the windows before and after the change. A deletion or a moved start date makes that wider than the changed row. It deletes before it inserts, because an insert cannot remove the cost of a day whose tariff is gone. Both are worked out in [the insert cannot remove a row](01-stored-costs.md#an-insert-cannot-remove-a-row).

It is also the cheap version already, which is why there is no later step that makes it cheap. The backfill is the whole mechanism. Given a date range, it recomputes a corrected tariff without InfluxDB and without deleting a summary. The expensive fallback deletes the summaries and rebuilds them from InfluxDB. Only a mode with sub-day prices needs that, and the first of those arrives in C1, which is where it is built.

Deleting the summaries here instead would ship a price edit that re-queries 1,800 days from InfluxDB, for a correction that PostgreSQL can do on its own.

This is the step where the mechanism is proven. Compare the totals for a day, a month, a year and a top-10 ranking against the values from before, with a tolerance (see [01-stored-costs.md](01-stored-costs.md#correctness-check)). Compare `savings` and the amortization as well, not only `grid_revenue`. They are what step 3 is there for, and a period without a day of zero export does not exercise it. If anything here is wrong, it is wrong for one sensor and the fix is cheap.

Do not continue until the numbers match.

Two comments in the code stop being true at this step. Both explain a decision rather than describing a line, so a reader will believe them. The heatmap names finance sensors as its example of the calculated path. `AmortizationCalculator.cache_key` explains the price in its key with "the savings sensor is computed per day from the price valid on that day and joined fresh on every query". The price stays in the key and the reason changes, so rewrite the reason rather than deleting it.

### A4 — The grid pair: `grid_energy_costs` and `grid_base_fee`

Same mechanism, now with the base fee in it.

`grid_base_fee` is the odd one. It has no energy dependency at all, so its backfill comes from the calendar. It needs a row for every day in range, not only for days that have an energy row. The fee falls due whether the meter reported or not. Drive that calendar from the summaries, which is the only set of days a value row can belong to (see [01-stored-costs.md](01-stored-costs.md#backfill-instead-of-rebuild)).

It is also the first value in `summary_values` that is not a measurement, and `MeasuredRange` asks that table for the first measured day without naming a field. Narrow that query here. Otherwise the amortization silently spreads the measured savings over days the meter never saw (see [it is also the first value that is not a measurement](01-stored-costs.md#it-is-also-the-first-value-that-is-not-a-measurement)).

`grid_costs` stays computed, as the sum of the two. It is the first composed sensor whose parts are both stored, so it splices through the coalesce helper that A3 built. Coalesce each part, and keep the whole NULL only when both parts are missing (see [a composed sensor must tolerate a missing part](01-stored-costs.md#but-a-composed-sensor-must-tolerate-a-missing-part)). A tariff without a base fee otherwise makes `grid_costs` NULL on every day. That is the worst version of the error, because it hits every installation that never enters a fee.

### A5 — The consumer costs

The bulk of the enum values: the grid and PV pair for the house, the heat pump, the wallbox and all 20 custom consumers. About 46 values, 40 of them the custom pairs.

They share a shape, so they convert as one group. This is also where the base fee share has to keep working. A consumer carries the share of the fee that matches its share of the grid import, and that share is now computed once per day rather than per query.

That makes a consumer cost more than energy times a price. The backfill therefore carries the fee term as well, guarded against a day with no grid import at all, which would otherwise divide by zero. The share is scaled against the **corrected** grid import, which is why the collection step runs after `SummaryCorrector`.

### A6 — The awkward ones

`battery_savings`, `opportunity_costs` and `traditional_costs`. Each needs its own thought:

- `battery_savings` mixes both price types in one sensor and has optional grid-share dependencies.
- `opportunity_costs` prices a difference, the PV that was consumed instead of exported.
- `traditional_costs` has a dynamic dependency list and carries the full base fee.

None of that needs a new declaration. The sensor keeps doing its own arithmetic in `#calculate_with_prices` (see [01-stored-costs.md](01-stored-costs.md#the-sensor-does-the-multiplication-not-the-step)). What needs care is the backfill. These three do not reduce to one energy field times one price, so each needs its own expression. `traditional_costs` needs the one whose dependency list depends on the configuration.

This is also where the three learn to return no value on a day with no energy, instead of a zero (see [01-stored-costs.md](01-stored-costs.md#three-sensors-do-not-follow-that-rule-yet)).

A stored `traditional_costs` freezes that configuration into the day it was written, and `SummaryInvalidator` covers only half of it. It notices a custom consumer moving in or out of `house_power` and resets the summaries. It does not notice a heat pump or a wallbox being configured for the first time. It compares only the sensors that both configurations have, and a new one counts as a harmless change. Today that is invisible, because the cost is recomputed on every page view. Stored, the old days keep the old list forever.

So add the dependency list of `traditional_costs` to what the invalidator compares. Do not widen the comparison to react to every added sensor. A new sensor with no history is the common case, and a full rebuild is the wrong price for it.

### A7 — Retire the price join

Only now, when every price-multiplying sensor is stored. The three query builders stop reading `#required_prices`, and the price CTE and its joins go with them.

`#required_prices` itself stays on the `FinanceBase` sensors that price something, because the InfluxDB path reads it for the sub-day views. Three sensors lose it:

- `savings` and `solar_price` are not `FinanceBase` sensors, so the InfluxDB path never collects from them anyway. They declared it solely so the CTE would build the columns their spliced SQL referenced.
- `total_costs` is a `FinanceBase` sensor, so the InfluxDB path does collect from it. But it carries a `calculate` block and prices nothing of its own (see [current-state.md](current-state.md#which-sensors-are-finance-sensors)). Its two parts declare the same two price types, so removing its declaration changes nothing there either.

Once the CTE is gone, nothing reads any of the three.

**Two documents are updated in this step**, and both are guides somebody follows rather than prose nobody reads.

`docs/sensor-reference.md` carries the "Finance Sensors" chapter that a new cost sensor is written from. Block A falsifies it section by section. The example declares `stored: false`, the SQL calculation multiplies by a price column, and a subsection describes the price CTE that A7 removes. While rewriting it, settle the contradiction it already carries. One example derives `TotalCosts` from `Definitions::Base` and another from `FinanceBase` (see [current-state.md](current-state.md#which-sensors-are-finance-sensors)).

`docs/sensor-sql-queries.md` is worse off. Three of its eight worked examples are built on the join: "Cost Calculation with Price JOIN", "Savings for a Month" and "Time Series with Cost Calculation". They print the `price_ranges` CTE and its two joins as the shape a money query has. After A7 that shape does not exist, and the file is a set of queries that no longer run.

Expect the SQL path to get faster here, not slower. A window function and up to two joins per daily row are gone.

### A8 — Consumer tariffs

See [02-consumer-tariffs.md](02-consumer-tariffs.md). Still no InfluxDB.

1. The consumer on a price entry, unique per name, start date and consumer, with its validations
2. A way to end a consumer tariff. The mode arrives in C1, so at this point it needs a flag of its own. Do **not** solve it by duplicating the default tariff under the consumer name
3. The lookup that resolves consumer, inherit and default in that order, with the old amount-only lookup kept as a wrapper
4. `price_inputs` per definition, and the consumer key resolved from the base sensor, so the summary step prices each term with the tariff of its own consumer (see [02-consumer-tariffs.md](02-consumer-tariffs.md#which-consumer-a-term-belongs-to))
5. `grid_energy_costs` becomes the sum over the consumers with a tariff of their own, plus the remainder at the default rate, clamped at zero (see [02-consumer-tariffs.md](02-consumer-tariffs.md#what-the-grid-costs-are-made-of))
6. `traditional_costs` prices each of its parts with the rate of that part. That lowers `savings` where a cheaper consumer tariff exists
7. Settings UI: consumer field, list grouped by consumer
8. `get_prices` reports the consumer, then `bin/llm-test`. The tool answers one object per price name today, and a consumer turns that into a set. A model that reads a consumer rate as the household rate is wrong by the whole difference between them
9. Widen the recalculation of A3 by the consumer, then recompute the affected days with it

Step 9 is the same mechanism as A3 and not a re-summarize. A consumer tariff is still one amount per day, so PostgreSQL can do the whole correction on its own.

---

## Block B — InfluxDB infrastructure

Still no user-visible feature. This is the step that decides whether block C is usable at all.

### B1 — A windowed daily batch

Extend `Influx::DailyBatch` with a per-day windowed mean that **keeps its buckets**, instead of reducing them to min, max and average as it does today. Hang it into a per-day stream that already reads the sensor, rather than writing a second program. Only a sensor that declares min, max or average has such a stream, and the split does not follow the sensor category. The battery pair has one and `custom_power_XX` does not (see [reuse the per-day stream](03-sub-day-prices.md#reuse-the-per-day-stream-where-there-is-one)). Ask it only for the sensors a finance sensor is made of, never for every sensor the summary sums.

Benchmark it against the existing per-day programs first. That same class documents a windowed variant measured at 4 to 11 times slower. This one avoids the cause, but that is a prediction until it is measured. Three things have to be in the benchmark, or it measures the easy case (see [what the shape query actually costs](03-sub-day-prices.md#what-the-shape-query-actually-costs)):

1. The real number of sensors and the real window count, because the response grows a hundredfold per sensor and day. Benchmark 20 custom consumers, which is 53 sensors, not the 13 an installation without them needs.
2. The Ruby that parses the response, not the InfluxDB time alone.
3. A single day on its own, because the batch is skipped below two days and the current day is rebuilt that way all the time.

Run it against the local InfluxDB that the specs use. No development system has 20 custom consumers, so the data for the benchmark is written first: 20 consumers and their grid shares, over enough days to fill a chunk. That container exists for the tests alone and `bin/influxdb-restart.sh` recreates it, so filling it costs nothing (see `AGENTS.md`).

A local container is not a remote InfluxDB, and the 2265 ms the batch is compared against were measured against a remote one. So the benchmark compares the new program with the old one on the same machine, and reports the ratio rather than the absolute time.

**This is a stop point.** Present the numbers. Whether block C goes ahead is decided from them, not by the step that produced them. Do not build on top of a batch whose benchmark has not been read. Two facts belong in that report, because they decide how much a bad number costs: time-of-use runs on an hourly window and is cheaper by a factor of four, so a benchmark that fails at 15 minutes does not necessarily block C1.

---

## Block C — Sub-day prices

See [03-sub-day-prices.md](03-sub-day-prices.md). Time-of-use comes first. It needs no collector, no new sensors and no price series, only the shape path.

### C1 — Time-of-use

1. The mode and the slots on a price entry, validations per mode, the slots restricted to the full hour, and the amount column made nullable in both the database and the model (see [data model](03-sub-day-prices.md#data-model))
2. The shape-times-amount path in `SummaryBuilder`, zone-aware, on an hourly window, window count from the timeframe, one shape per priced term and never per dependency (see [the shape belongs to the term](03-sub-day-prices.md#the-shape-belongs-to-the-term-not-to-a-dependency))
3. The time-of-use path in `Influx::FinanceCalculation`, which is two different jobs. The chart points get a price each. The hourly totals get split at the slot boundaries first, because they carry one number for up to 99 hours (see [the hourly totals have none](03-sub-day-prices.md#the-hourly-totals-have-none))
4. Settings UI: the time slot editor
5. `get_prices` reports no single amount and carries the slots instead, then `bin/llm-test`
6. The expensive tier of the price-change handling. A time-of-use edit needs sub-day data, so its range of summaries is deleted and rebuilt (see [01-stored-costs.md](01-stored-costs.md#a-price-change-must-not-rebuild-from-influxdb)). Answer the amortization cache here as well, which tier 2 invalidates too early. That answer is a [stop point](#where-a-step-stops)

Spec the equivalence while the path is written. A time-of-use tariff that carries the same amount in every slot must return what the `fixed` entry it replaces returned. It is the one test that catches a shape taken at the wrong level, and it catches it for every sensor at once.

### C2 — Dynamic prices

Both directions at once: spot prices for what is bought, and direct marketing (#4947) for what is fed in.

1. `electricity_price` and `feed_in_price` in the registry: the money-per-kWh unit, averaged only, never stored, and in the `depends_on` of nothing (see [a price sensor is a query input](03-sub-day-prices.md#a-price-sensor-is-a-query-input-never-a-dependency))
2. Document their sensor mapping, with the `tibber-collector` values as the example
3. The dynamic path in `SummaryBuilder`, on the batch from B1, quarter-hourly
4. The dynamic path in `Influx::FinanceCalculation`: resample the price series to the chart interval, and split the hourly totals into quarter hours before multiplying, for the same reason as C1 step 3
5. The grace period for days that never receive price data, plus the marker it needs, taught to **both** places that judge whether a day is stale (see [missing data](03-sub-day-prices.md#missing-data))
6. In the form: warn that switching an old entry to `dynamic` discards its cost history, and refuse the mode outright while no price sensor is configured (see [dynamic without a price sensor](03-sub-day-prices.md#dynamic-without-a-price-sensor))
7. The price sensors in `list_sensors`, with descriptions that separate them from `get_prices`. Answer the `t` flag here too, which a sensor without a summary cannot honor for a daily timeframe, and that answer is a [stop point](#where-a-step-stops) (see [they are the first sensors with no summary behind them](03-sub-day-prices.md#they-are-the-first-sensors-with-no-summary-behind-them)). Then `bin/llm-test`

Direct marketing was a step of its own in an earlier draft. It is not one. The dynamic path multiplies an energy series by a price series and does not care which of the two tariffs it reads. Building it for `electricity` alone and adding `feed_in` afterwards is more work, not less. The only part specific to feed-in is that the revenue can go negative, which [01-stored-costs.md](01-stored-costs.md#negative-values) already requires.

Split it off again only as a scope decision, if direct marketing has to ship later than spot prices.

---

## Not on this roadmap: energy sharing

[04-energy-sharing.md](04-energy-sharing.md) is thought through, but it is not a step here. A roadmap lists work that can be started.

It waits on something outside SOLECTRUS. The two sensors it prices, `community_import_power` and `community_export_power`, say how much of the grid import and export went through the community. Only the grid operator knows that split, and it publishes it in its smart meter portal. No collector reads one, and a single collector cannot cover them all. Every operator runs its own portal, most without an API and behind a login. The first version can therefore be a CSV import rather than a polling collector. And #5334 is a discussion, not a decision.

It joins the roadmap once the data source is settled. It slots in after block C, because it prices its sensors with the ordinary tariff machinery from A8.

One thing to keep in mind while building block A, without building for it. If energy sharing ever arrives, `grid_energy_costs` and `grid_revenue` have to subtract the community part before applying the regular rate. Do not make that impossible.

---

## What this order buys

- **The irreversible steps come early and small.** A3 adds one enum value and one sensor, so a wrong mechanism is wrong once.
- **The InfluxDB risk sits in one step.** If B1 benchmarks badly, block A still stands and only C is in question.
- **Nothing is thrown away.** A8 never touches the price CTE that A7 deletes. C1 is never written as one query per slot, because B1 came first.
- **Every step is releasable, and none of them is released on its own.** A1, A8, C1 and C2 are features. A2 to A7 carry no feature, and that is not the same as carrying nothing a user sees. The property earns its keep on the branch. Every step can be reviewed, run and compared against the one before it.

A3 to A6 each change one number that a user can read. A day the meter never reported costs nothing today, and it has no cost at all afterwards. It therefore leaves the rankings and the `min` of a period (see [a day without energy is NULL, not zero](01-stored-costs.md#a-day-without-energy-is-null-not-zero)). A8 lowers `savings` wherever a consumer tariff is cheaper. Each of those needs its line in `.changelog/unreleased.md`, in the same commit, like any other visible change. A2 and A7 are the only two that really change nothing a user can see.
