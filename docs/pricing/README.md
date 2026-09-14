# Pricing

How SOLECTRUS turns energy into money, and what it takes to support tariffs that change during a day. None of it is implemented.

## Where to start

Read [current-state.md](current-state.md) first. Every other file builds on it. Most of the traps in them come from details of the code that are not obvious.

Then read two short sections of the roadmap before starting any step: [where the work happens](roadmap.md#where-the-work-happens), which names the branch and what that loosens, and [where a step stops](roadmap.md#where-a-step-stops), which lists the four points that need a decision from outside the work.

| File                                             | Feature                                     | Issue               |
| ------------------------------------------------ | ------------------------------------------- | ------------------- |
| [current-state.md](current-state.md)             | How prices and costs work today             | —                   |
| [roadmap.md](roadmap.md)                         | The order to build it in, and the status    | —                   |
| [01-stored-costs.md](01-stored-costs.md)         | Move money from query time into the summary | #5340               |
| [02-consumer-tariffs.md](02-consumer-tariffs.md) | A separate tariff per consumer              | #4850, #5227        |
| [03-sub-day-prices.md](03-sub-day-prices.md)     | Time-of-use and spot market prices          | #4832, #2150, #4947 |
| [04-energy-sharing.md](04-energy-sharing.md)     | Renewable energy communities                | #5334               |

## How to read them

These files answer whether the tariff models can work. So they carry the decisions and the traps. They do not carry the statements, the queries or the column names that will implement them. Where a rule is worth defending, it says so and why. How to write it down is the choice of the implementer.

[current-state.md](current-state.md) is the exception and names classes and methods on purpose. It is the map the other files point at. When one of them describes a seam without naming it, that seam is in the map.

## What it is for

Three pricing models, each of which can also apply to the feed-in tariff:

| Mode            | Description                               | Example                          |
| --------------- | ----------------------------------------- | -------------------------------- |
| **Fixed**       | One amount per kWh                        | 0.30 per kWh from 2024-01-01     |
| **Time-of-Use** | Fixed amounts per time slot within a day  | HT 0.30 (6-22h), NT 0.20 (22-6h) |
| **Dynamic**     | Spot market price, changes every 15min/1h | Tibber, aWATTar                  |

Plus a separate tariff per consumer, for example a heat pump on its own meter. All of these change over time, independently of each other:

```
2020-02-01  Fixed 0.28 EUR/kWh, feed-in 0.082 EUR/kWh, base fee 10 EUR/month
2021-06-01  Fixed 0.32 EUR/kWh (new contract), base fee 12 EUR/month
2023-01-01  Tibber (dynamic spot prices), base fee 8 EUR/month
2024-03-01  aWATTar (dynamic, different provider), base fee 9 EUR/month
2025-01-01  Time-of-Use HT 0.30 / NT 0.20 EUR/kWh (§14a module 3), base fee 12 EUR/month
            + Heat pump on separate meter: fixed 0.22 EUR/kWh
2025-07-01  Tibber (back to dynamic), base fee 8 EUR/month, heat pump stays on ToU
2026-01-01  Feed-in switches to dynamic (direct marketing), base fee 5 EUR/month
2026-06-01  Join energy community: community import 0.15, community export 0.12
```

The `prices` table is a timeline. A change of tariff is a new row, and the history keeps whatever it had. Nothing in these documents can break that.

## The one decision everything hangs on

Money is never stored today. A cost is calculated when a page is rendered, by joining the `prices` table onto the daily energy sums. That works because a day has exactly one price. Time-of-use and dynamic pricing end that, so the money has to be calculated once per day and stored.

That is [01-stored-costs.md](01-stored-costs.md). It is a prerequisite for [03-sub-day-prices.md](03-sub-day-prices.md), and it decides the order of everything else.

## Already settled

- **Currency** (#2797, released via #5623). A display concern, handled by the `CURRENCY` env var. No formula changes.
- **Monthly base fee** (#2560). Written on a branch of its own, and released through `develop` on its own. It changes the `prices` table and splits `grid_costs` in two, so everything here starts from it. See [A1 in the roadmap](roadmap.md#a1--the-monthly-base-fee).

Related but out of scope: #3198 (CO₂ from a time-dependent grid intensity). It has the same calculation shape as [03-sub-day-prices.md](03-sub-day-prices.md), a consumption series times a factor series. Whatever is built there must be reusable.

## Open questions

Every question that blocked a step is answered. Each answer sits in the file it belongs to rather than in a list of its own. What is still open belongs to [04-energy-sharing.md](04-energy-sharing.md#open-questions), which is why it is [not on the roadmap](roadmap.md#not-on-this-roadmap-energy-sharing).

The four [stop points](roadmap.md#where-a-step-stops) are not open questions of that kind. Each of them is decided from something the work produces first, a measured number or a trade-off between two answers that both work. They are listed so that a step does not silently choose one of them on its own.

## The things most likely to go wrong

Every one of these is quiet. None raises, and none looks wrong on a chart.

1. A stored cost is NULL where a computed one was zero. A composed sensor inherits that NULL and loses whole days. It starts at the very first stored sensor, not at the first pair of them. See [01](01-stored-costs.md#but-a-composed-sensor-must-tolerate-a-missing-part).
2. The storage change is irreversible if done as one wipe. See [01](01-stored-costs.md#backfill-instead-of-rebuild) for the backfill that avoids it.
3. A stored cost can silently disagree with the stored energy. See [01](01-stored-costs.md#order-of-operations).
4. The base fee is the first stored value that is not a measurement. The amortization reads the table as if every value were one. See [01](01-stored-costs.md#it-is-also-the-first-value-that-is-not-a-measurement).
5. The sub-day shape is taken per dependency instead of per priced term. A time-of-use tariff then stops agreeing with the fixed one it replaced. See [03](03-sub-day-prices.md#the-shape-belongs-to-the-term-not-to-a-dependency). The declaration that prevents it has to carry how a term is computed, not only its name. See [02](02-consumer-tariffs.md#a-name-is-not-enough).
6. A term whose windows are all zero divides by zero. `NaN` then goes into a `float` column that accepts it. See [03](03-sub-day-prices.md#a-term-with-no-shape).
7. The windowed batch can be too slow, and the whole sub-day feature rests on it. See [03](03-sub-day-prices.md#query-cost).
8. Dynamic mode has no history and no repair. The retry marker has to reach both places that judge a day. See [03](03-sub-day-prices.md#missing-data).
9. A sub-day cost lands in the hot path, because the current day is rebuilt while the user watches. See [03](03-sub-day-prices.md#the-current-day-is-the-hot-path-not-the-rebuild).
10. A time-of-use slot starts between two hours. The hourly shape then prices that hour at a rate the tariff never had. See [03](03-sub-day-prices.md#data-model).
11. A spot price is applied to the hourly totals as one amount for up to 99 hours, because that path has no data points to price one by one. See [03](03-sub-day-prices.md#the-hourly-totals-have-none).
12. `list_sensors` advertises `get_totals` for a price sensor. The tool then answers null for every timeframe of a day or more. See [03](03-sub-day-prices.md#they-are-the-first-sensors-with-no-summary-behind-them).
13. A price sensor is declared as a dependency of a cost sensor. Every installation without a spot price collector then loses its whole cost section. Nothing raises. The sensors are simply gone from the registry, and with them the menu entry. See [03](03-sub-day-prices.md#a-price-sensor-is-a-query-input-never-a-dependency).
14. A tariff is edited in a way the correction never sees, so the costs behind it stay old. A console session and a summary run that is already in flight both do it. See [01](01-stored-costs.md#two-edits-the-correction-never-sees).
