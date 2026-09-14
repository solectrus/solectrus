# Energy Sharing

Renewable energy communities: neighbors share solar power. The grid import and the grid export of a household each split into a community part and a regular part, priced differently.

Prerequisite reading: [current-state.md](current-state.md). Depends on [01-stored-costs.md](01-stored-costs.md) and [02-consumer-tariffs.md](02-consumer-tariffs.md).

Issue: #5334. Still a discussion, not a decision. This file records what was worked out so far.

## How it works in reality

Known as EEG in Austria and Energy Sharing in Germany. The community acts as an additional electricity supplier with its own rate.

Two things arrive from different places, and keeping them apart is the whole design:

- **The split** comes from the smart meter portal of the grid operator, as an external measurement. Typically 15-minute interval data, available the next day. This is energy data, not price data.
- **The rate** is agreed separately, in a contract. It is an ordinary tariff and it lives in the `prices` table.

So the community is not a new pricing mode. It is two new energy sensors plus two ordinary consumer tariffs.

## New sensors

Written to InfluxDB by an external collector that reads the smart meter portal:

- `community_import_power` is the power received from the community, a subset of `grid_import_power`.
- `community_export_power` is the power fed into the community, a subset of `grid_export_power`.

And two new finance sensors, stored like the rest:

- `community_import_costs` is `community_import_power` at the community import rate.
- `community_export_revenue` is `community_export_power` at the community export rate.

## Prices

The community rates are consumer tariffs. They use the mechanism from [02-consumer-tariffs.md](02-consumer-tariffs.md) with the new sensors as the consumer key:

```
name=electricity  starts_at=2026-06-01  mode=fixed  value=0.30   consumer=all
name=electricity  starts_at=2026-06-01  mode=fixed  value=0.15   consumer=community_import_power
name=feed_in      starts_at=2026-06-01  mode=fixed  value=0.082  consumer=all
name=feed_in      starts_at=2026-06-01  mode=fixed  value=0.12   consumer=community_export_power
```

Nothing stops a community from using a time-of-use or dynamic rate. The mode column carries it, and the shape-times-amount path prices it, with no extra work.

## The calculation

```
Grid import costs:
  community:  community_import_power * 0.15 / 1000
  regular:    (grid_import_power - community_import_power) * 0.30 / 1000

Feed-in revenue:
  community:  community_export_power * 0.12 / 1000
  regular:    (grid_export_power - community_export_power) * 0.082 / 1000
```

`grid_energy_costs` and `grid_revenue` have to subtract the community part before applying the regular rate, clamped at zero. See the corrector question below. That is a change to sensors that already exist and are already stored, so it invalidates historic values for every day the community was active.

## Late data

The split arrives the next day, after the summary for that day was already written without it. So the day has to be recalculated.

[03-sub-day-prices.md](03-sub-day-prices.md#missing-data) needs the same mechanism for a late price series. Write the day without the values that are missing, mark it for a rebuild, and drop the marker after a grace period. Build it once, for both.

## Open questions

- **Is the community part of the grid, or beside it?** The calculation above treats `community_import_power` as a subset of `grid_import_power`, so the two never double count. The open part is the display. Grid and community can be two bars or one split bar, and that is not decided.
- **The base fee.** A community membership can carry its own monthly fee. The model allows a base fee only on an electricity price with no consumer. That restriction [stays](02-consumer-tariffs.md#the-base-fee-does-not-follow), so a membership fee is added into the one entry. Whether that is good enough here is the open part.
- **Does `SummaryCorrector` need to know?** It sits outside the scaling today, and by construction rather than by decision. The corrector only sees the sensors that `SummaryBuilder` hands it: the consumers, their `_grid` shares and the two grid sources. A community sensor is in none of those lists. `extract_power_pairs` would pair it with nothing anyway, because it carries no `_grid` suffix. That is probably the right place for it, because a community sensor slices the import rather than consuming it. The consequence is what needs deciding. An unscaled community part can exceed a scaled `grid_import_power`, so "subtract the community part before applying the regular rate" needs a clamp at zero. [The grid costs](02-consumer-tariffs.md#what-the-grid-costs-are-made-of) already need the same clamp, for the same reason.
- **Which collector?** None exists. Every grid operator portal is different, and most have no API. The first version can therefore be a CSV import rather than a polling collector.

## Steps

None yet. This is deliberately [not on the roadmap](roadmap.md#not-on-this-roadmap-energy-sharing), because the data source is unsettled. Once the data source is settled, the work slots in after block C. It prices its sensors with the ordinary tariff machinery from A8:

1. Sensor definitions for `community_import_power` and `community_export_power`
2. Finance sensors `community_import_costs` and `community_export_revenue`, stored like the rest
3. `grid_energy_costs` and `grid_revenue` subtract the community part
4. A collector or CSV importer for the smart meter portal
5. Re-summarize the affected days
