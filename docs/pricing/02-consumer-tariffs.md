# Consumer Tariffs

A separate tariff per consumer, for example a heat pump on its own meter at a cheaper rate.

Prerequisite reading: [current-state.md](current-state.md). Depends on [01-stored-costs.md](01-stored-costs.md), though not strictly. See "Can this ship first" below.

Issues: #4850, #5227.

## Data model

A price entry gains a consumer. The default is "all", the tariff for every consumer without an entry of its own. Any other value is a sensor name, for example `heatpump_power`.

Keep it a free string rather than an enum, so a new sensor type needs no migration. Make sure that the value is a configured power sensor at runtime. The uniqueness of an entry is then per name, start date and consumer, and the settings list groups by consumer.

Uniqueness lives in a database index, not only in a model validation. The index is what the timeline rests on. Two entries for the same name, date and consumer make the lookup return an arbitrary one of them. So the existing unique index over name and start date is replaced by one that includes the consumer.

That is also why the default is the string `all` and not NULL. PostgreSQL treats two NULLs as different values in a unique index. A nullable consumer column would therefore let an installation collect any number of default tariffs for the same date, without a single error. A column with a default and a NOT NULL constraint cannot. Do not "simplify" it to a nullable column later.

### Ending a consumer tariff

A consumer tariff cannot be ended by deleting rows, because the lookup always takes the newest consumer entry on or before the date. A heat pump that goes back to the household tariff would keep its old rate forever.

So there is a mode that means "from here on, use the default again". [03-sub-day-prices.md](03-sub-day-prices.md) introduces a mode for other reasons, and this is one of its values. The roadmap has consumer tariffs before that mode. In this order the flag arrives on its own first, and the mode absorbs it later.

Either way, do not solve it by writing a duplicate of the default tariff under the consumer name. That silently stops following later changes to the default.

## Price lookup

Three steps, in this order:

1. Take the newest entry for this consumer.
2. Treat "inherit" as if there were none.
3. Otherwise fall back to the default consumer.

It returns the whole entry rather than an amount, because the caller has to read the mode as well.

The existing amount-only lookup stays as a thin wrapper. The MCP tool and the InfluxDB path use it, and changing its return type would ripple further than necessary. Once every caller has moved, it can go.

The lookup runs per day and per consumer, so load the whole table once per summary run. It is a few dozen rows. Do not issue a query per finance sensor per day.

## Price inputs

The sensor keeps doing its own arithmetic in `#calculate_with_prices` (see [01-stored-costs.md](01-stored-costs.md#the-sensor-does-the-multiplication-not-the-step)). What changes here is what gets handed to it. `prices` stops being one amount per type, because two dependencies of the same sensor can now be on different tariffs.

So the caller has to resolve a price per dependency. For that it needs to know which tariff applies to which dependency. `depends_on` cannot answer that:

- Several finance sensors mix price types. `battery_savings` pairs discharge with electricity and charge with feed-in. `opportunity_costs` uses `inverter_power − grid_export_power`.
- `traditional_costs` declares `depends_on` as a Proc that mirrors `total_consumption.dependencies`, so `static_dependencies` returns an empty array.

The mapping belongs in the definition, next to the other price declarations. Call it `price_inputs`. It names each priced quantity and the price type that applies to it.

The key is the quantity that gets multiplied by a price, not always a raw dependency. For `grid_energy_costs` the two are the same sensor. For `house_costs_pv` the quantity is the house consumption that did not come from the grid, one term built from two dependencies. `battery_savings` has two such terms, with a different price type each. Name the term, because [03-sub-day-prices.md](03-sub-day-prices.md#the-shape-belongs-to-the-term-not-to-a-dependency) reads this same declaration to decide what it takes the sub-day shape of. Shaping the dependencies separately gives a different number.

### A name is not enough

A declaration of name plus price type carries the term for this file and fails the next one. `03` has to build the term **per window**. For six sensors that term is a clamped difference: `max(house_power − house_power_grid, 0)`, and the two battery shares. That expression lives inside `#calculate_with_prices` and nowhere else. A caller that holds only the name "the PV share of the house" cannot reproduce it. It falls back to shaping the two dependencies on their own, which is exactly the error that `03` writes a whole section against.

So `price_inputs` declares three things per term: the price type, the consumer key, and how the term is computed from the dependencies. The third one is what makes the declaration useful to more than one caller.

Then let `#calculate_with_prices` build its terms through the same declaration, instead of repeating the arithmetic. Otherwise the clamp exists twice, in the definition and in the sub-day step, and the two only have to disagree once. The equivalence spec of [C1](roadmap.md#c1--time-of-use) catches that disagreement, but only after somebody writes the second copy wrong.

### Which consumer a term belongs to

A tariff is configured on the consumer the user sees, the heat pump. The cost sensors read its grid share and its PV share, so the resolver has to get from those back to the consumer.

The path exists. Every `_grid` share already knows the sensor it is a share of, and the summary step already asks that question elsewhere. So the rule has three parts: the base sensor where there is one, the sensor itself where there is not, and the default for anything aggregate such as the grid import or the inverter.

The battery shares answer the same question and map to the battery sensors. That is harmless and needs no exception. Nobody signs a contract for a battery, so no tariff exists under that key and the lookup falls back to the default. Do not let the settings form offer it.

**The consumer key applies to electricity only.** The PV share of a consumer is valued with the feed-in tariff, and that tariff belongs to the plant rather than to the consumer. A heat pump with its own contract does not change what the kWh would have earned as an export. A feed-in price is therefore always resolved with the default consumer.

`traditional_costs` is the interesting case. It sums house, heat pump, wallbox and the excluded custom consumers. It prices **each** of them with its own rate rather than applying one rate to the sum. It does the opposite today, one rate for the whole sum. That shortcut goes away.

The reason is what the sensor claims to answer: what the same consumption would have cost without PV. Without PV the heat pump is still on its own contract. A §14a rate follows the grid connection and the controllable load, not the photovoltaics. A household rate would compare against a contract that does not exist.

Say once what that does to the numbers, because it looks like a regression. `traditional_costs` falls as soon as a cheaper consumer tariff exists, and `savings` falls with it. That is a correction, not a loss. PV saves less on energy that was cheap to begin with.

## What the grid costs are made of

`grid_energy_costs` prices the whole grid import with the default tariff today. With a consumer on its own rate that is no longer the bill. Part of the same import is settled at the rate of the consumer.

So the formula gets one level deeper. Every consumer that has a tariff of its own is priced with its own grid share at its own rate. What is left of the import is priced with the default rate:

```
grid_energy_costs =  Σ  consumer_grid_share × consumer_rate
                   + (grid_import − Σ consumer_grid_share) × default_rate
```

This is a generalization, not a change. With no consumer tariff configured every rate is the same number. The sum telescopes, and the result is the grid import at the default rate, to the last digit. An installation that never opens the feature sees no difference at all.

Two things to get right:

- **Only subtract consumers that have their own tariff.** Subtracting every consumer share would make the remainder meaningless. It would also expose the result to every rounding of the splitter.
- **Clamp the remainder at zero.** `SummaryCorrector` scales the grid shares against a target that includes what the battery discharged from grid energy. Energy that took the battery detour therefore counts at the consumer and not in the import. A consumer share can exceed the import it is subtracted from. A negative remainder would silently pay money back.

That second point is worth stating plainly. `grid_energy_costs` and the sum of the consumer costs are not the same number, and they were not the same number before this change either. The grid costs answer what the grid connection cost. The consumer costs answer what each consumer used, battery detour included.

## The base fee does not follow

The base fee belongs to the grid connection, and the model allows a monthly amount only on an electricity price (see [roadmap.md](roadmap.md#a1--the-monthly-base-fee)). A consumer tariff therefore carries no fee of its own.

A heat pump on a genuinely separate meter does have a second base fee in reality, and so can a membership in an energy community. The restriction stays anyway: one grid connection, one fee per period. `grid_base_fee` stays one number rather than a sum. Whoever pays two fees adds them up in the one entry.

The reason is `base_fee_share`. A sensor declares its share of _the_ fee, and the share is scaled by the part of the grid import that belongs to the sensor. Two fees turn that single declaration into a question of which fee is meant, and both backends ask it. That is a large change for an arrangement that no SOLECTRUS installation can currently even describe.

## Can this ship first

Technically yes. A consumer tariff is still one rate per day, so the current price join can carry it: one join per consumer instead of the two fixed ones for electricity and feed-in.

Do not do it. [01-stored-costs.md](01-stored-costs.md) deletes that whole mechanism, so the work is thrown away. It is only worth it if time-of-use and dynamic pricing are cancelled.

## Steps

Step A8 in the [roadmap](roadmap.md#a8--consumer-tariffs). It is the last step of the PostgreSQL-only block, and it needs no Flux query.
