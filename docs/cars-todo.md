# Cars: todo

The plan for the car support, in the order of the work. [cars.md](cars.md) describes what
exists. When an item is done, move its description to cars.md and remove it here. A design
decision that is in neither file is lost.

| Topic              | Content                                                     |
| ------------------ | ----------------------------------------------------------- |
| 1. First release   | the car section in Helios                                   |
| 2. Open            | the views of a short timeframe for more than one car        |
| 3. Later additions | work outside the two issues, and the postponed manual input |
| 4. Simplifications | the open points of the review of the branch                 |

## 1. First release

The dashboard has the cars and the detection of the charging sessions. One item of the
first release is left.

- [ ] The car section in Helios

Helios has a static sensor list with `car_battery_soc` alone. It needs a car section: the
user adds a car, and Helios writes the `INFLUX_SENSOR_CAR_*_<n>` variables. Helios goes
into its release after the dashboard. Until then, Helios writes
`INFLUX_SENSOR_CAR_BATTERY_SOC`, which stays a permanent alias of the first car.

## 2. Open

These points have no design yet:

- The hours view and a day, for one car and for "all". Their charts `car_charging` and
  `car_charging_costs` show the wallbox alone, because a session belongs to a full day.
- The charts of "all" that show a column for each car in its color. The distance chart
  does this already. The charging and the cost charts show the sum of the cars.

## 3. Later additions

None of these changes the design above.

- Manual odometer readings, for the history before the odometer sensor or for a car
  without one. This is postponed. It needs a table for the readings, and
  `Influx::DailyDiffs` must merge them with the InfluxDB readings. A new
  reading changes the distance of each day up to the readings around it, so these days must
  be built again. Two readings that are months apart give the same distance to each day
  between them, so the page must mark such days. A car without an odometer variable makes
  `Sensor::Config` depend on the database. The dashboard writes nothing to InfluxDB, so the
  readings cannot go there.
- Automatic assignment without a guess. A sensor `car_connected_<n>` or an `identifier`
  (RFID, MAC, ISO 15118) gives the car of a session also when the heuristics give no
  answer. With one car, it also finds a guest charge.
- The assignment of many sessions at once, for example each session of a period that is
  not assigned. After the backfill, an installation with more than one car can have many
  such sessions.
- MCP for one car of many: the charged energy, the cost and the rates of a selected car.
- Hiding a sold car. Its `active_until` ends its period (see
  [A change of car](cars.md#a-change-of-car)), and it stays in the select for the history. A setting can
  hide it there. Its number stays used.
- The proposal of an offsite session. When a car reports a connection and the wallbox
  gives no power, SOLECTRUS can make an incomplete `offsite` session. This needs
  `car_connected_<n>`.
- The import from evcc, with the sessions and the identifier. An imported session needs a
  column `source`, or a third kind.
- More than one wallbox. The session gets a `wallbox_id`, and the unique index of the
  detection holds it too.
- A wider window for a user who drives little. The window of a day has 29 days
  ([cars.md](cars.md#a-window-for-each-day)), and below 100 km it gives no rate. A window
  that grows to a minimum distance, for example 1,000 km, gives a steadier rate but a
  smaller seasonal difference. Do this when users report rates that jump from day to day.
  Open: the minimum distance, and how the window grows near today.
- The savings against a combustion car
  ([#2407](https://github.com/solectrus/solectrus/issues/2407),
  [discussion #5796](https://github.com/orgs/solectrus/discussions/5796)) and the
  amortization calculator ([#2416](https://github.com/solectrus/solectrus/issues/2416)).
  The fuel prices come from the `oil_bulletin` provider of `public-data-collector`, which
  writes `Fuel:price_petrol` and `Fuel:price_diesel` (EUR/l, weekly) to InfluxDB. The
  comparison also needs the fuel type and the consumption (l/100 km) of the combustion car
  as a configuration.

## 4. Simplifications

A review of the branch found these points. The simplifications are done. Measure the summary
build before and after each change that touches it.

Not done, because with up to five cars each query takes about 1 ms. Do them when more cars
or more sessions make them count:

- `Car::Ledger` reads the distances and the sessions of each car in queries of its own.
  `Car::DailyRates.for` can read them for all cars at once and give them to the ledgers.
- `Car::Balance` reads the guest totals and the totals that are not assigned in two
  queries. One query with `FILTER` gives both.

Checked and kept:

- The detection also runs without a wallbox. Its `persist` removes the old wallbox
  sessions of each day that it builds. If the detection skips these days, the sessions
  stay after the user removes the wallbox.
