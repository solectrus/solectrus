# Cars: todo

The plan for the car support. [cars.md](cars.md) describes what exists. When an item is
done, move its description to cars.md and remove it here. A design decision that is in
neither file is lost.

None of these items changes the design in cars.md.

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
  - The list of the wallbox sessions of "all" gets a button for the admin. It opens a
    modal with a select of the car and assigns each session that is not assigned in the
    timeframe to this car.
    Checkboxes in the rows are worse, because the list loads its pages one after another.
  - The select offers no guest, because a wrong guest mark hides the energy of a car.
  - A session outside the period of use of the car stays not assigned. The flash gives the
    number of these sessions.
  - An `update_all` skips the callbacks and the validations. It must therefore set
    `assigned_manually`, or the next detection changes the car again. A condition on the
    period of use replaces `car_active`.
  - The parts of a charge over midnight are all in the filter, so they all get the car.
  - The pages read the sessions directly, so no summary and no cache needs a new build.
- The import from evcc, with the sessions and the identifier. An imported session gets the
  origin `evcc` and keeps the kind `wallbox` (see
  [cars.md](cars.md#charging-sessions)). The detection must then leave a charge of the
  import alone, so it makes no second session of it.
- More than one wallbox. The session gets a `wallbox_id`, and the unique index of the
  detection holds it too.
- The removal of `car_battery_soc` from the database. The migration
  [add_car_support](../db/migrate/20260927102209_add_car_support.rb) keeps the value in
  `field_enum`, so an older version still runs on the database. A build of a day writes
  `car_battery_soc_1` but does not delete the old rows. Only a reset of the summaries
  removes them. When no older version runs on the database any more, a migration must
  delete the rows of `car_battery_soc` in `summary_values` and remove the value from
  `field_enum`. PostgreSQL has no DROP VALUE, so this needs a new type.
