# Consumer Tariffs

A separate electricity tariff per consumer, for example a heat pump on its own meter at a cheaper rate.

Step A6 in the [roadmap](roadmap.md#a6--consumer-tariffs). Requires [01](01-stored-costs.md). Issues #4850, #5227.

## Data model

A price entry gains a `consumer`: `all` (the default tariff) or the name of a configured power sensor, e.g. `heatpump_power`.

- A free string, not an enum, so a new consumer type needs no migration. Validate at runtime that it is a configured power sensor.
- `NOT NULL` with default `all`. A nullable column would let duplicate default tariffs pass the unique index, because PostgreSQL treats NULLs as distinct.
- The unique index over name and start date becomes name, start date and consumer.
- The PV share of a consumer is always valued at the default feed-in price, which belongs to the plant. A heat pump contract does not change what its kWh would have earned as export. (A feed-in entry with a consumer only becomes meaningful with [energy sharing](04-energy-sharing.md).)
- The base fee stays on the default electricity tariff only. One grid connection, one fee; whoever pays two adds them in the one entry.

### Who can have a tariff

The heat pump, the wallbox and the custom consumers that are excluded from `house_power`. Each of them is a part of `total_consumption` on its own, so its energy is priced exactly once.

A custom consumer inside the house is not offered: its energy is also part of `house_power`, which is priced at the default rate. The battery is not offered either.

### Ending a consumer tariff

The lookup takes the newest consumer entry, so a consumer tariff cannot be ended by deleting rows. An entry says so itself through a `mode`: `fixed` (an amount per kWh) or `inherit` ("use the default again from here on", without an amount). `inherit` is only valid with a consumer. [03](03-sub-day-prices.md#data-model) adds two more modes to the same column.

Do not end it by copying the default tariff under the consumer name. The copy stops following later changes of the default.

## Lookup

`Price::Schedule` resolves per date and consumer: the newest entry of the consumer, unless it is `inherit`; otherwise the default. It returns the entry, not only the amount, because callers will need its mode. `Price.at` stays as a thin wrapper for existing callers.

## Which consumer a term belongs to

Each priced term (see [01](01-stored-costs.md#priced-terms)) names its consumer: the base sensor of a `_grid` share (via `#corresponding_base_sensor`), the sensor itself where there is none, and the default for aggregates such as the grid import. A consumer without a tariff of its own falls back to the default.

## Grid costs

The grid import is billed partly at the consumer rates:

```
grid_energy_costs =  Σ consumer_grid_share × consumer_rate
                   + max(grid_import − Σ consumer_grid_share, 0) × default_rate
```

- Only consumers with their own tariff are subtracted. Without any, the formula is the old one, to the last digit.
- The remainder is clamped at zero. `SummaryCorrector` scales the grid shares against a target that includes battery discharge from grid energy, so a share can exceed the import.

`grid_energy_costs` and the sum of the consumer costs are not the same number, and never were. One answers what the grid connection cost, the other what each consumer used.

## Traditional costs

`traditional_costs` prices each consumer at its own rate instead of one rate for the sum. Without PV the heat pump would still be on its own contract. As a result `traditional_costs` and `savings` fall where a cheaper consumer tariff exists. That is a correction, and it goes into the changelog.

## Other readers

`ChargingSession::Cost` and `Car::Ledger::WithoutPv` use the wallbox tariff and `Heatpump::Comparison` the heat pump tariff, all through `Price::Schedule`. The recalculation of [01](01-stored-costs.md#recalculation-after-a-price-change) takes its range from the entries of the same name and consumer; a change of the default also covers the days on which a consumer inherits it. `ChargingSession.reprice` runs when the wallbox tariff or the default changes.

## MCP

`get_prices` reports the consumer of each entry. A model that reads a consumer rate as the household rate is wrong by the whole difference. Run `bin/llm-test` afterwards.

## Not first

Consumer tariffs could ship on the current price join, with one join per consumer. Don't: [01](01-stored-costs.md) removes that join, so the work would be thrown away.
