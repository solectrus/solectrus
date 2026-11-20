# Pricing

How SOLECTRUS turns energy into money, and what it takes to support tariffs that change during a day. Only the monthly base fee is implemented so far.

## In short

SOLECTRUS should support tariffs whose price changes during a day: fixed time slots (time-of-use) and spot market prices (dynamic). It should also support a separate tariff for a single consumer.

**The idea.** Today money is calculated every time a page is shown: the energy of a day times the price of that day. That only works while a day has one price. So in future the cost of a day is calculated once and stored, while the data within the day is still at hand.

**The parts.**

- **Stored costs (01).** The cost of each day is stored next to its energy. No tariff changes; this is the groundwork for everything else. When a price changes, the affected days are recalculated from the stored energy.
- **Consumer tariffs (02).** The heat pump, the wallbox or a consumer on its own meter can have its own electricity price. Without one, the normal price applies.
- **Sub-day prices (03).** Time-of-use and dynamic work the same way: the energy of a day is spread over 15-minute windows by its course, and each window is multiplied by its price. A collector delivers the dynamic prices. A day without prices has no cost.
- **Energy sharing (04).** Written down, not planned, because there is no data source yet.

**The order.**

1. **Block A** touches only the database: store the costs (one sensor as a pilot, then all), remove the old price calculation, then the consumer tariffs. The base fee is already done.
2. **Block B** measures whether the 15-minute query is fast enough, also on slow hardware. It decides whether block C is built this way.
3. **Block C** brings time-of-use first, then dynamic prices.

Everything after the base fee stays on one branch until the end, because the new database fields cannot be taken back once released.

## Where to read on

Read [current-state.md](current-state.md) first, then the [roadmap](roadmap.md). Each feature file holds the decisions for its feature and the traps that come with them. It does not hold queries or column names.

| File                                             | Feature                                     | Issue               |
| ------------------------------------------------ | ------------------------------------------- | ------------------- |
| [current-state.md](current-state.md)             | How prices and costs work today             | —                   |
| [roadmap.md](roadmap.md)                         | Order of the work, status, stop points      | —                   |
| [01-stored-costs.md](01-stored-costs.md)         | Move money from query time into the summary | #5340               |
| [02-consumer-tariffs.md](02-consumer-tariffs.md) | A separate tariff per consumer              | #4850, #5227        |
| [03-sub-day-prices.md](03-sub-day-prices.md)     | Time-of-use and spot market prices          | #4832, #2150, #4947 |
| [04-energy-sharing.md](04-energy-sharing.md)     | Renewable energy communities (not planned)  | #5334               |

## Goal

Three pricing modes, for the electricity price and for the feed-in price:

| Mode            | Description                              | Example                          |
| --------------- | ---------------------------------------- | -------------------------------- |
| **Fixed**       | One amount per kWh                       | 0.30 per kWh from 2024-01-01     |
| **Time-of-use** | Fixed amounts per time slot within a day | HT 0.30 (6-22h), NT 0.20 (22-6h) |
| **Dynamic**     | Spot market price, changes every 15 min  | Tibber, aWATTar                  |

Plus a separate tariff per consumer, for example a heat pump on its own meter. All of it changes over time, independently:

```
2020-02-01  Fixed 0.28, feed-in 0.082, base fee 10/month
2023-01-01  Tibber (dynamic), base fee 8/month
2025-01-01  Time-of-use HT 0.30 / NT 0.20 (§14a module 3), base fee 12/month
            + heat pump on its own meter: fixed 0.22
2026-01-01  Feed-in switches to dynamic (direct marketing)
```

The `prices` table stays a timeline: a change of tariff is a new row, and the history keeps what it had.

## The one decision

Money is not stored today. A cost is calculated at render time by joining `prices` onto the daily energy sums. That only works because a day has exactly one price. Time-of-use and dynamic prices end that, so the cost has to be calculated once per day, while sub-day data is still reachable, and stored. That is [01](01-stored-costs.md), and it decides the order of everything else.

## Out of scope

- **Currency** is a display concern (`CURRENCY`, #2797), already done.
- **CO₂ from a time-dependent grid intensity** (#3198) has the same shape as [03](03-sub-day-prices.md): a consumption series times a factor series. Whatever is built there should be reusable for it.
