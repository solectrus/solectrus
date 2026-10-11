# Cars: todo

The plan for the car support, in the order of the work. [cars.md](cars.md) describes what
exists. When an item is done, move its description to cars.md and remove it here. A design
decision that is in neither file is lost.

| Topic              | Content                                                      |
| ------------------ | ------------------------------------------------------------ |
| 1. First release   | the car section in Helios                                    |
| 2. Later additions | work after the first release, and the postponed manual input |

## 1. First release

The dashboard has the cars and the detection of the charging sessions. One item of the
first release is left.

- [ ] The car section in Helios

Helios has a static sensor list with `car_battery_soc` alone. It needs a car section: the
user adds a car, and Helios writes the `INFLUX_SENSOR_CAR_*_<n>` variables. Helios goes
into its release after the dashboard. Until then, Helios writes
`INFLUX_SENSOR_CAR_BATTERY_SOC`, which SOLECTRUS reads as the variable of the first car.

## 2. Later additions

None of these changes the design above.

- Manual odometer readings, for the history before the odometer sensor or for a car
  without one. This is postponed. It needs a table for the readings, and
  `Influx::DailyDiffs` must merge them with the InfluxDB readings. A new
  reading changes the distance of each day up to the readings around it, so these days must
  be built again. Two readings that are months apart give the same distance to each day
  between them, so the page must mark such days. A car without an odometer variable makes
  `Sensor::Config` depend on the database. The dashboard writes nothing to InfluxDB, so the
  readings cannot go there.
- Automatic assignment without a guess. An `identifier` (RFID, MAC, ISO 15118) gives the
  car of a session also when no car reports a connection and the heuristics give no answer.
  The request in [#5836](https://github.com/solectrus/solectrus/issues/5836) names this
  source. A session that no car was connected to stays not assigned today. With an
  identifier, the detection can mark it as a guest charge.
- The assignment of many sessions at once. After the backfill, an installation with more
  than one car can have many sessions that are not assigned. The design:
  - The list with the filter "not assigned" gets a button. It opens a modal with a select
    of the car and assigns each session of the filter and the timeframe to this car.
    Checkboxes in the rows are worse, because the list loads its pages one after another.
  - The select offers no guest, because a wrong guest mark hides the energy of a car.
  - A session outside the period of use of the car stays not assigned. The flash gives the
    number of these sessions.
  - An `update_all` skips the callbacks and the validations. It must therefore set
    `assigned_manually`, or the next detection changes the car again. A condition on the
    period of use replaces `car_active`.
  - The parts of a charge over midnight are all in the filter, so they all get the car.
  - The pages read the sessions directly, so no summary and no cache needs a new build.
- Full MCP support for the cars: the charged energy, the charging cost, the driving cost
  and the rates, for all cars and for one car. Today MCP has no tool for them
  ([cars.md](cars.md#mcp)).
- The import from evcc, with the sessions and the identifier. An imported session gets the
  origin `evcc` and keeps the kind `wallbox` (see
  [cars.md](cars.md#charging-sessions)). The detection must then leave a charge of the
  import alone, so it makes no second session of it.
- More than one wallbox. The session gets a `wallbox_id`, and the unique index of the
  detection holds it too.
- A wider window for a user who drives little. The window of a day has 29 days
  ([cars.md](cars.md#rates-and-driving-cost)), and below 100 km it gives no rate. A window
  that grows to a minimum distance, for example 1,000 km, gives a steadier rate but a
  smaller seasonal difference. Do this when users report rates that jump from day to day.
  Open: the minimum distance, and how the window grows near today.
- The savings against a combustion car
  ([#2407](https://github.com/solectrus/solectrus/issues/2407)), as a topic of its own.
  The fuel prices come from the `oil_bulletin` provider of `public-data-collector`, which
  writes `Fuel:price_petrol` and `Fuel:price_diesel` (EUR/l, weekly) to InfluxDB. The
  comparison also needs the fuel type and the consumption (l/100 km) of the combustion car
  as a configuration. Neither the car nor these savings count in the amortization
  ([discussion #5796](https://github.com/orgs/solectrus/discussions/5796)).
- The removal of `car_battery_soc` from the database. The migration
  [add_car_support](../db/migrate/20260927102209_add_car_support.rb) keeps the value in
  `field_enum`, so an older version still runs on the database. A build of a day writes
  `car_battery_soc_1` but does not delete the old rows. Only a reset of the summaries
  removes them. When no older version runs on the database any more, a migration must
  delete the rows of `car_battery_soc` in `summary_values` and remove the value from
  `field_enum`. PostgreSQL has no DROP VALUE, so this needs a new type.
