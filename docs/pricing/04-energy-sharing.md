# Energy Sharing

Renewable energy communities: neighbors share solar power. The grid import and the grid export of a household each split into a community part and a regular part, priced differently.

Issue #5334. Still a discussion, not a decision, and [not on the roadmap](roadmap.md#not-on-this-roadmap-energy-sharing) because no data source exists. This file records what was worked out so far. Depends on [01](01-stored-costs.md) and [02](02-consumer-tariffs.md).

## How it works

Known as EEG in Austria and Energy Sharing in Germany. The community acts as an additional electricity supplier with its own rate. Two things arrive from different places:

- **The split** comes from the smart meter portal of the grid operator: 15-minute interval data, available the next day. This is energy data, not price data.
- **The rate** is agreed in a contract. It is an ordinary tariff and lives in the `prices` table.

So the community is not a new pricing mode. It is two new energy sensors plus two ordinary consumer tariffs.

## Sensors and prices

An external collector writes two sensors to InfluxDB: `community_import_power`, a subset of `grid_import_power`, and `community_export_power`, a subset of `grid_export_power`. Two priced sensors are stored like the rest: `community_import_costs` and `community_export_revenue`.

The community rates are [consumer tariffs](02-consumer-tariffs.md) with the new sensors as the consumer:

```
electricity  2026-06-01  fixed  0.30   consumer=all
electricity  2026-06-01  fixed  0.15   consumer=community_import_power
feed_in      2026-06-01  fixed  0.082  consumer=all
feed_in      2026-06-01  fixed  0.12   consumer=community_export_power
```

A community with a time-of-use or dynamic rate needs no extra work; the mode carries it.

## The calculation

`grid_energy_costs` and `grid_revenue` subtract the community part before applying the regular rate, clamped at zero:

```
import:  community_import × 0.15  +  max(grid_import − community_import, 0) × 0.30
export:  community_export × 0.12  +  max(grid_export − community_export, 0) × 0.082
```

The clamp is needed because `SummaryCorrector` does not see the community sensors: they are no consumers and carry no `_grid` share. That is probably right, because a community sensor slices the import rather than consuming it. [The grid costs](02-consumer-tariffs.md#grid-costs) need the same clamp for the same reason.

## Late data

The split arrives the next day, after the summary of that day was written without it. Whatever imports the split deletes the summaries of the days it wrote, and they rebuild.

## Open questions

- **Display.** Grid and community can be two bars or one split bar.
- **The base fee.** A community membership can carry its own monthly fee. The model allows a base fee only on the default electricity tariff, so a membership fee is added into that entry. Whether that is good enough is open.
- **Which collector?** None exists. Every grid operator portal is different, and most have no API. The first version can be a CSV import.
