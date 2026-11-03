# Cars

How SOLECTRUS shows electric cars: their state, the distance they drive, the energy they
charge and what the driving costs. SOLECTRUS supports up to five cars. This document
describes what exists, and [cars-todo.md](cars-todo.md) holds the plan. Change this
document in the same pull request as the code. A design decision that is in neither file is
lost.

This document holds the behavior and the decisions. The thresholds and the exact rules of
an algorithm are in the comment of its class, which the text names.

The design answers two issues: consumption and cost per kilometer
([#3517](https://github.com/solectrus/solectrus/issues/3517)) and more than one car
([#5836](https://github.com/solectrus/solectrus/issues/5836)).

## What the car page answers

- What does the driving of a day, a month or a year cost?
- What do 100 km cost (`EUR/100 km`), and how much energy does the car use for them,
  with the charge losses (`kWh/100 km`)?
- What does the charging cost, split into PV, grid and offsite?
- How much energy went into the car, at the wallbox and offsite?
- How far does the car go on a full battery? This shows the loss of battery capacity and
  the season.

Each answer is for one car or for all cars together. The difficult part is the time
between charging and driving, because the car drives on energy of other days. A window of
14 days before and after each day solves this (see [Rates](#rates-and-driving-cost)).

## Code map

| Class                               | Job                                                                     |
| ----------------------------------- | ----------------------------------------------------------------------- |
| `Car`                               | a car: number, name, color, period of use, `Car.configured`             |
| `Car::Rules`                        | the values of the rules for places, visits, drives and charges          |
| `Car::PeriodChange`                 | what follows when the period of use of a car changes                    |
| `Sensor::Cars`                      | the numbers and the sensor names of the cars, without a database        |
| `ChargingSession`                   | a charge of a car, at the wallbox or offsite                            |
| `ChargingSession::Sums`             | the sums of a set of sessions: count, energy, cost, PV share            |
| `ChargingSession::Detection`        | finds the wallbox sessions in the power curve of a day                  |
| `ChargingSession::OffsiteDetection` | proposes offsite sessions from the state of charge of a day             |
| `ChargingSession::Proposal`         | the proposals of offsite sessions: accept, dismiss, estimate            |
| `ChargingSession::AddressLookup`    | the position of the address of an offsite session, from Nominatim       |
| `Car::Ledger`                       | the car days of a date range: distance, session sums, state of charge   |
| `Car::Driving`                      | the rates of each day from its window                                   |
| `Car::EnergySources`                | the driven energy and its cost split into PV, grid and offsite          |
| `Car::Report`                       | the numbers of a timeframe, for the page and for its charts             |
| `Car::Spans`                        | the lowest and the highest value of the periods of one kind             |
| `Car::DayTimeline`                  | the drives, the charging sessions and the state of charge of a day      |
| `Car::Live`                         | the live values of the wallbox and of each car                          |
| `Car::RangeEstimate`                | the range of a car without a range sensor                               |
| `Car::AdminOnlyDays`                | the days that only the admin sees: today and yesterday                  |
| `Car::Comparison`                   | the cost of the cars against a combustion car, and its page             |
| `Car::FuelPrices`                   | the weekly fuel prices, from InfluxDB                                   |
| `Car::Payment`                      | an income or an expense of a car, for the comparison                    |
| `CarSelection`                      | the selected car (`/cars/2/…`) on the car page and in the lists         |
| `Car::Section`                      | the two columns of the overview, driving and charging, and their charts |
| `Place`, `Place::VisitDetection`    | the places where the cars stood, and the visits there                   |
| `McpServer::Tools::CarCosts`        | the figures of a `Car::Report` for an MCP client (see [MCP](#mcp))      |

The car page and its charts read one `Car::Report`. A column of a chart and the tile of the
same period therefore read the same days and show the same number.

## Three layers

| Layer            | Says                            | Where it lives      |
| ---------------- | ------------------------------- | ------------------- |
| Wallbox          | how much energy flows, and when | `wallbox_*` sensors |
| Car _n_          | the state of one vehicle        | `car_*_<n>` sensors |
| Charging session | which car got which energy      | PostgreSQL record   |

A car sensor never carries energy, and a wallbox sensor never carries a vehicle. The
charging session is the only link. A daily sum cannot be split between vehicles, so the
session is the base of the energy and the cost of each car. A session also gives the PV
share at charge time. A car that charges at night therefore does not get the PV share of
noon.

## Cars

A car has a number from 1 to `Sensor::Cars::MAX = 5`. The number names its sensors and its
record in the table `cars`. So the sensors, the daily values and the charging sessions of a
number all name the same car.

The environment variables stay the source of the sensor configuration, because Helios
writes them. Car 2 reads `INFLUX_SENSOR_CAR_ODOMETER_2`, `INFLUX_SENSOR_CAR_BATTERY_SOC_2`,
`INFLUX_SENSOR_CAR_RANGE_2`, `INFLUX_SENSOR_CAR_CONNECTED_2`,
`INFLUX_SENSOR_CAR_LATITUDE_2` and `INFLUX_SENSOR_CAR_LONGITUDE_2`. One of the six
variables is enough for a number. A variable with a number outside 1 to `MAX` is ignored
with a warning.

A car variable without a number is the variable of car 1, so an installation with one car
needs no number. `INFLUX_SENSOR_CAR_BATTERY_SOC` is from the time before cars had numbers.
No variable without a number is deprecated. If both are set, the numbered variable wins
with a warning.

The table `cars` holds what the environment cannot:

| Column             | Meaning                              | NULL means                                     |
| ------------------ | ------------------------------------ | ---------------------------------------------- |
| `id`               | the number, no sequence              | –                                              |
| `name`             | the name of the car                  | the short name, or else I18n ("Car 2")         |
| `short_name`       | at most five characters              | – (required, a new car takes its number)       |
| `active_from`      | the first day of use                 | – (required, by default the installation date) |
| `active_until`     | the last day of use                  | the car is in use                              |
| `color`            | a hex code like `#3b82f6`            | the default color (sky blue)                   |
| `battery_kwh`      | the usable capacity of the battery   | no capacity                                    |
| `fuel_type`        | `petrol`, `diesel` or `lpg`          | no comparison with a combustion car            |
| `fuel_consumption` | l/100 km of the combustion car       | – (required with a fuel)                       |
| `combustion_tax`   | the yearly tax of the combustion car | no tax                                         |

`Car.configured` gives the cars of the configured numbers. It creates a missing car on the
first request that needs one, so a user with one car has nothing to do. It is not part of
`Sensor::Config`, because a database write at configuration time couples the two layers.

The number of a car never changes, because the daily values store its history under the
sensor name with the number. SOLECTRUS never removes a car, so a sold car keeps its number
and its history. The car management page (`/settings/cars`) edits the columns. It adds no
car, because a configured number gets its car by itself.

### Name and color

The name of a car sensor is the car name plus the role, for example "Model Y (Odometer)".
The state of charge stands beside the home battery on the power balance, so its name has
the form of the home battery, with the short name: "ZOE SOC". The short name stands where
a long name takes too much space. A new car has its number as short name, which says less
than the default name "Car 2", so it shows the default name.

The color of a car marks it where cars stand side by side, and in the charts of all cars.
The sensors of a car keep their own colors, because each sensor has its own meaning.

### The period of use

A car that replaces another car gets a new number and a period of use. The new car gets an
`active_from`, and the old car an `active_until` of the day before. A new car never writes
to an InfluxDB field of another car.

Outside its period of use, a car counts for nothing, also when its sensors still send data.
This happens when the sensors of a sold car stay configured, or when two numbers read the
same field. The summary build stores no daily value of the car outside its period, the
pages offer only the cars in use in their timeframe, and the charts of a day show no curve
of the car. A charging session can only go to a car whose period holds its time.

`Car::PeriodChange` applies a new period at once:

- A wallbox session of the car outside the new period loses the car, also a car that the
  user chose.
- The proposals and the visits of the car outside the new period go.
- The summaries of the changed days go. The next build makes them again, with the daily
  values of the car and the records of each step. A move of `active_from` by years
  therefore builds these years again.

An offsite session of the user has no detection, so the model refuses a period that leaves
an accepted offsite session of the car outside. The same applies to a payment (see
[Comparison](#comparison-with-a-combustion-car)).

A change of the variable of a sensor with daily values calls `Summary.reset!` and replaces
its history.

## Sensors

| Sensor                 | Variable                            | Daily summary               | Meaning                      |
| ---------------------- | ----------------------------------- | --------------------------- | ---------------------------- |
| `car_battery_soc_<n>`  | `INFLUX_SENSOR_CAR_BATTERY_SOC_<n>` | `min`, `max`, `avg`, `last` | state of charge (%)          |
| `car_odometer_<n>`     | `INFLUX_SENSOR_CAR_ODOMETER_<n>`    | `sum`                       | odometer (km)                |
| `car_range_<n>`        | `INFLUX_SENSOR_CAR_RANGE_<n>`       | `avg`                       | remaining range (km)         |
| `car_connected_<n>`    | `INFLUX_SENSOR_CAR_CONNECTED_<n>`   | none                        | car plugged in (boolean)     |
| `car_latitude_<n>`     | `INFLUX_SENSOR_CAR_LATITUDE_<n>`    | none                        | latitude (degrees)           |
| `car_longitude_<n>`    | `INFLUX_SENSOR_CAR_LONGITUDE_<n>`   | none                        | longitude (degrees)          |
| `car_max_range_<n>`    | none, calculated                    | `avg`                       | range at a full battery (km) |
| `car_charging`         | none, chart only                    | none                        | charged energy               |
| `car_charging_costs`   | none, chart only                    | none                        | charging cost                |
| `car_consumption_rate` | none, chart only                    | none                        | `kWh/100 km`                 |
| `car_cost_rate`        | none, chart only                    | none                        | `EUR/100 km`                 |
| `car_driving_energy`   | none, chart only                    | none                        | energy used for driving      |
| `car_driving_costs`    | none, chart only                    | none                        | driving cost                 |
| `car_battery_soc`      | none, chart only                    | none                        | state of charge of one car   |
| `car_distance`         | none, chart only                    | none                        | distance of the cars         |
| `car_max_range`        | none, chart only                    | none                        | max. range of one car        |

The registry makes the seven sensors of a car for each number up to `MAX`, and
`Sensor::Config` removes a number without a configuration. These sensors hold the data.
The car page shows only the chart-only sensors, which have no number: the car select
chooses the car, and the chart menu chooses the chart. The state of charge of the one car
in use also has a chart on the power balance, beside the home battery.

All car sensors need the permission `:car`. The rates, the energy used and the driving cost
exist when a car has an odometer, because the energy and the cost can come from the offsite
sessions alone.

A car sensor is a state (`state` in the definition): its value holds until the next
reading, at any age. A car reports only while it is online, and some sources send only a
change, for example TeslaMate. A parked car can therefore send nothing for days, and a
maximum age hides its state. The live view, the charts of a day, the daily values, the
visits and the assignment of the sessions therefore read the last reading before their
time. A daily value like the average state of charge counts each 5 minutes of the day the
same, so a parked day keeps its value and a drive does not count more (see `state` in
[sensor-reference.md](sensor-reference.md)). A position has one more limit: it ends when
the odometer rises by more than 1 km after it, because then the car drove away. A small
rise is the end of the drive home, which can come after the position.

A boolean sensor like `car_connected_<n>` accepts a boolean, a number or a text such as
`on`, because a collector for MQTT often sends text (`Sensor::Units::Boolean`).

`car_battery_soc` is in the release v1.3.3, and the migration
[add_car_support](../db/migrate/20260927102209_add_car_support.rb) does not change it. So
an older version of the application still runs on the database. A new car sensor with data
before today resets the daily summaries at the next start, like any added sensor.

### Distance

`car_odometer_<n>` is a meter (`meter: true`) and stores the distance of each day as the
aggregation `sum`. The odometer is also a state, so a day can have one reading or none. The
odometer at a midnight is the last reading before it (`Influx::DailyDiffs`). So the daily
values add up exactly: the sum of a range is the odometer at its end minus the odometer at
its start. A day before the first reading has no value, so an odometer that comes after the
installation gives no distance of 0 for the time before it.

If the collector was down while the car drove, the next reading shows the distance of the
gap. This distance goes to the day of that reading. A later reading never changes the
distance of an earlier day.

A wrong reading of the odometer adds its jump to the distance of a day. Some collectors send
0 while the car is offline, so the jump back is the full odometer. `Sensor::MeterReadings`
therefore leaves out a reading of 0 or less and a reading clearly below the reading before
it. A reading that the next reading confirms stays, because then the odometer changed for
good, for example after a new source.

### Maximum range

`car_max_range_<n>` is `car_range_<n> × 100 / car_battery_soc_<n>`. The summary build
calculates it from the daily averages of `car_range` and `car_battery_soc`. A query of a
period reads the stored average and not the formula, because the formula over the averages
of a period is not the average of its days.

## Charging sessions

A charging session is a charge of a car. The kind says where the energy flowed:

| Kind      | Charged at              | Origin                                | Energy and cost from    |
| --------- | ----------------------- | ------------------------------------- | ----------------------- |
| `wallbox` | own wallbox             | `detection`                           | wallbox curve, splitter |
| `offsite` | public or other wallbox | `user`, or `detection` for a proposal | manual input, estimate  |

The column `origin` says who made the row. It has no default, so each writer must name
itself. An accepted proposal keeps `detection`. The detection changes only its own rows, so
a later import, for example from evcc, will get an origin of its own.

A `wallbox` session is in one of three states:

| State        | `car_id` | `guest` | Counts for             |
| ------------ | -------- | ------- | ---------------------- |
| car          | set      | false   | the car                |
| guest        | NULL     | true    | the guest and "all"    |
| not assigned | NULL     | false   | no car, "all" names it |

A guest charge is a decision of the user, and "not assigned" is an open task. The column
`assigned_manually` marks a state that the user chose. The detection never makes a guest,
so a guest charge always has this mark. A wallbox session stores its energy, its grid share
(`kwh_grid`), its cost and the cost of its grid share (`cost_grid`). So the split into PV
and grid needs no price when a page reads it.

An `offsite` session always has a car and never the guest mark. The user enters its energy
and its cost. It is in one of three states:

| State     | `assigned_manually` | `dismissed` | `kwh`            | `cost`   | Counts |
| --------- | ------------------- | ----------- | ---------------- | -------- | ------ |
| proposal  | false               | false       | estimate or NULL | NULL     | no     |
| accepted  | true                | false       | required         | required | yes    |
| dismissed | true                | true        | any              | any      | no     |

A session that the user enters is accepted at once. The scope `effective` gives each
session that counts: each wallbox session, and each accepted offsite session. Each reader
of the numbers uses it.

A session stores the state of charge of its car at its start and at its end (`soc_from`,
`soc_to`). A change of the car in the form clears it, because it belongs to the car.

A session belongs to the local date of its start. A charge at 23:30 therefore stays on the
day of the distance beside it. The detection splits a wallbox session at midnight, so the
energy of each day stays on its day. An offsite session over midnight stays one session.

### The list

The list of the sessions (`/cars/1/charging_sessions/offsite/2025`) shows one kind at a
time, of the selected car, "all" or the guest. Its sums are the sessions that count, so
they agree with the chart. A charge over midnight is one row (`ChargingSession.joined`) and
counts once, while the data keeps a session for each day, so the daily sums stay exact. A
charge that goes on shows without its end. The table does not store this state, like for
an ongoing visit.

The admin also sees the sessions to review: the proposals, and the wallbox sessions that
are not assigned. The sums leave them out. A session that is not assigned can be the charge
of any car, so the list of each car and of the guest names it too, and its link opens the
list of "all". A filter shows the sessions to review alone.

The offsite sessions have a map over their list, for the admin. The wallbox sessions have
no map, because they all share one place. The area of a circle shows the share of the
energy.

The form of a session:

- The user changes the car, the guest mark and the note of a wallbox session. The detection
  writes its time, energy and cost, so the form shows them read-only.
- A new session is always `offsite`, because a guest charge that no wallbox measured has no
  energy and no cost. Only an offsite session can be deleted.
- An offsite session records a charge that took place, so the form refuses a time after now
  (`ChargingSession::EnteredTime`).
- A save accepts a proposal, so the form needs the cost. The user can also dismiss a
  proposal. "Dismiss all" serves a time without receipts
  ([#6021](https://github.com/solectrus/solectrus/issues/6021)). It dismisses only the
  proposals that the list showed, so a proposal of a later build stays.

The form shows the loss of a charge: 1 − rise ÷ 100 × `battery_kwh` ÷ `kwh`. A loss in each
row of the list added no value. The loss needs a large rise, because the state of charge
has whole percents. The form names it a rough estimate, because `battery_kwh` is seldom
exactly the capacity that the state of charge refers to. A loss far from the usual values
is a sign of a wrong state of charge
([#6056](https://github.com/solectrus/solectrus/issues/6056)).

`ChargingSession::StateOfCharge` tells when the state of charge does not fit the energy.
Then the form explains this and shows no loss:

- A negative loss: the state of charge rose more than the energy explains. The scale of the
  state of charge changes with the temperature of the battery, so a point can hold a
  quarter less energy in winter.
- A rise far too small or too large for the energy, for example 75 → 75 % with 20 kWh. The
  car then reported no current values during the charge. A full car can take energy without
  a rise, so a rise to 99 % is never too small.

### The detection

`ChargingSession::Detection` finds the wallbox sessions in the wallbox curve of a day. Its
comment and the classes it names hold the rules. These are the decisions behind them:

- A session is a period with power. A short pause does not end it, because load management
  and PV surplus control make such pauses. `wallbox_car_connected` bridges a longer pause,
  but it never moves an end, because otherwise a charge before the sensor reports the
  connection loses its energy.
- A time without a reading is no data, not 0 W. A collector can fail for an hour while the
  car charges, so such a gap does not end a session. The sessions then keep the energy of
  the daily sum, which integrates across the gap.
- A session stores the times of the readings at its edges, not of the 5-minute buckets that
  find it (`Detection::Edges`).
- A session needs a minimum energy, because many wallboxes report a standby power.
- The energy and the grid share come from the integral of the power, like the daily sum.
- The grid share costs the electricity price and the PV share the feed-in price of the day.
  Without the power splitter, `kwh_grid` stays NULL, and the full energy gets the
  electricity price. Without a price, `cost` stays NULL, because zero is a wrong number.
  The car page then names the missing price.
- The state of charge at the end is the highest reading some time after the end, because a
  car that is offline during the charge reports its end late. A charge never lowers the
  state of charge, so a session with a lower state at its end gets no states.

The sessions of a day nearly hold the wallbox energy of the day, and never more.

### Which car charged

The candidates of a wallbox session are the cars whose period holds its day
(`Detection::CarAssignment`):

1. A candidate that reports a position away from home is excluded.
2. One candidate reports a connection during the session: that car.
3. A candidate that reports no connection is excluded, unless its state of charge rises
   during the session.
4. One candidate remains: that car.
5. More than one candidate remains: the car that the heuristics find.
6. Otherwise: not assigned.

Home is the place with the label "Home" (see [Places](#places)). A car at home does not
always charge, so home is no sign for a car. A car away from home is excluded also when it
reports a connection, because it charges at another charger. The connection comes from
`car_connected_<n>`, the sensor of the car and not of the wallbox. A car without this sensor
gives no sign and stays a candidate.

The heuristics use strong signs, because two cars cannot charge at the same time on one
wallbox. One candidate whose state of charge rises gets the session. A candidate whose
state of charge stays flat, or whose odometer rises during the session, is excluded.

The assignment never makes a guest. With one car and no connection sign, each session gets
this car, and the user marks a guest charge by hand. A session that no candidate was
connected to stays not assigned, because a wrong guest mark hides the energy of a car.

### When the detection runs

SOLECTRUS has no background processing. A detected session comes from the InfluxDB data of
one day, like a daily summary. So the detection is a step of the daily build
(`Summary::Steps`), with the rules for a missing and a stale day, the progress bar and the
MCP path of the build. "Delete the summaries" builds the sessions again.

A step runs on each day that the build makes, and only there. So a summary holds the daily
values and the records of each step, and a page waits only for a missing or a stale
summary. These changes remove the summaries, and the next build makes the days again:

- A new `VERSION` of a step resets the summaries at the next start
  (`Sensor::SummaryInvalidator`).
- A step that has something to do now, or a new sensor of a step, resets the summaries at
  the next start if its sensors have data before today. So an update from v1.3 with a
  wallbox builds the full history once.
- A new home removes the summaries at once, but only on the days on which a car can have a
  position (see [Places](#places)).
- A new period of use of a car removes the summaries of the changed days (see
  [The period of use](#the-period-of-use)).

A step does not ask for the permission of its sensors. A sponsorship opens pages, and the
records are there before it.

A new build keeps the state that the user chose and the note of a session, also when the
build moves its start (`Detection::Persistence`). A car that the detection chose stays as
long as the period of the car holds the day. An offsite session is never touched. Without a
wallbox, the detection does not run, so the sessions of an earlier wallbox stay as history.

### Proposals

`ChargingSession::OffsiteDetection` finds the charges of a car away from the wallbox. It is
a step of the daily build after the detection, and it writes each charge as a proposal of an
offsite session. A proposal does not count in the numbers of the car page.

A car gets proposals only with its odometer or its position besides the state of charge.
The odometer tells a drive from a charge, and the position tells home. With the state of
charge alone, each rise outside a wallbox session would be a proposal, for example a charge
at a socket at home.

The sign is a rise of the state of charge in one charge (`ChargingSession::SocRuns`). The
comment of `OffsiteDetection` holds the rules. These are the decisions behind them:

- A rise needs 5 percentage points, or 3 points while the car reports a connection. The
  connection tells a short charge from noise, for example a new calibration of the battery.
  A car that reports that it is not connected does not charge.
- A drive ends a rise, so two stops at chargers on one trip give two rises.
- A drive does not raise the state of charge. If one step between two readings holds a
  drive and a rise, the car charged within the step. A short such step at an edge of a
  charge adds its rise to the charge. Otherwise a car that reports every 20 minutes loses a
  large part of its rise ([#6056](https://github.com/solectrus/solectrus/issues/6056)).
  Against the receipts of one installation, the rule halved the spread of the energy per
  percentage point.
- A rise at home gives no proposal. There the energy came through the house, or the
  wallbox data has a gap.
- A rise during a wallbox session of the car, or shortly after it, belongs to that session,
  because a car that is offline during the charge reports the rise late. This does not
  apply to a car away from home.
- An offsite session of the user, or a dismissed proposal, blocks a proposal around its
  time.

A dry run against an installation with all offsite sessions entered by hand confirmed the
thresholds. A threshold of 2 points gave more proposals without a session, also with a
connection, and it found no more sessions. A threshold of 3 points gave no false proposal
and still found small charges.

A proposal stores the state of charge and the position during the rise. The position does
not come from the visits, because a short stop at a fast charger gives no visit. The
estimate is the rise times `battery_kwh`. It is the energy in the battery, so a receipt
shows about 5 to 10 % more for the losses. A change of `battery_kwh` gives each proposal of
the car a new estimate.

An entered or accepted offsite session gets the state of charge and the position of its
rise (`OffsiteDetection::EnteredState`). A wrong value is worse than none, so a session
gets them only when exactly one rise matches its time and no other session claims it.

### The position

An offsite session has one position: where the car charged (`ChargingSession::Location`).
The position always fits the address:

- A session with an address has the position of its address, from Nominatim (see
  [Address](#address)). Only a street or a building is precise enough.
- A session without an address has the position of its car during its rise, or none.

Without Nominatim (an empty `NOMINATIM_URL`), an address keeps the text of the user and has
no position of its own. Each session then gets the position of its car.

An address that Nominatim does not find is an error, and the form does not save it. A
request to Nominatim takes seconds, so the lookup runs before the save and outside its
transaction (`ChargingSession::AddressLookup`). Each caller that saves a new address must
run the lookup first.

Each address has one form: "DE-12345 Town, Main Street 15" (`Place::PostalAddress`).
Nominatim gives the country, the postcode and the spelling of the street. The town and the
house number come from the user, because Nominatim does not know each house number, and its
town can be a part of the town or a group of towns.

For a session without an address, the form offers the address at the position of the car.
A save with this address keeps the position of the car, because it is more exact. The build
never changes the position of an address.

The position of an address is often on the building and not at the charging station. So the
user can move the point on the map of the form, but not far. Only the position of an
address moves, because the build writes the other positions. The form offers to move the
point onto a charging station nearby, but it does not do this by itself, because it cannot
tell a position of the car from a position that the user set.

### A change of a price

A wallbox session gets the prices of its day when the detection finds it. A change of a
price gives a new cost to the sessions on the days of that price, before and after the
change. The new cost comes from the stored energy and its grid share, so the change reads
no InfluxDB data and gives the same cost as the detection.

The cost stays stored, and a page does not calculate it. Dynamic prices will change every
15 minutes and come from InfluxDB. The cost of a session then depends on when its power
flowed, so only the detection, which reads the power curve, can calculate it.

## Numbers of a period

`Car::Report` gives every number of a timeframe of a day or longer. It reads the days
through `Car::Ledger` and the rates through `Car::Driving`:

- Charged energy and charging cost: the sum of the charging sessions of the selected cars.
  A guest session counts for the guest and for "all". A session that is not assigned
  counts for no car.
- Split: the energy and the cost of the wallbox split into PV and grid with the power
  splitter. The offsite sessions are a part of their own.
- Distance: the sum of the daily distances of the selected cars. The average for each day
  divides it by the days on which a selected car was in use, not by all days of the period.
  A car counts from the first value of its odometer.
- Maximum range: the average of the daily values of one car. The cars of "all" have
  batteries of their own, so "all" has none.
- Driving cost and rates: the sum of the days of the period, each day at the rates of its
  window.

A chart column asks the same report for the days of the column.

### Rates and driving cost

The battery sits between charging and driving. If the car charges 50 kWh on Monday and
drives on it for a week, Monday alone gives 500 kWh/100 km and each other day 0.

Each day therefore takes its rates from a window: the day plus 14 days before and after it
(`Car::Driving`).

```
EUR/100 km of a day    =  driven cost of its window    ÷  distance of its window  × 100
kWh/100 km of a day    =  driven energy of its window  ÷  distance of its window  × 100
driving cost of a day  =  distance of the day          ÷  100  ×  EUR/100 km of the day
```

A period is the sum of its days, and its rate is this sum divided by its distance. A column
and the tile of the same period therefore show the same number, and the columns add up to
the tile.

The battery can hold more at the end of a window than at its start, or less. The charged
energy of the window is then too high, or too low. An example: a window charges 300 kWh,
and a battery of 50 kWh ends 40 points fuller. The car drove on 280 kWh, so the charged
energy is 7 % too high. The window therefore subtracts the change of the state of charge:

```
driven energy of a window  =  charged energy  −  k  ×  (state of charge at its end − at its start)
driven cost of a window    =  cost  ×  driven energy  ÷  charged energy
```

- The state of charge at the end of a day is a daily summary (`car_battery_soc_N`,
  aggregation `last`). The start of a window is the end of the day before it.
- `k` is the charged energy that raises the state of charge of the car by one percentage
  point (`ChargingSession.kwh_per_percent`). It is the median of the sessions of the car
  with a large rise. It holds the capacity of the battery and the loss of a charge in one
  number, so the correction needs no capacity.
- An offsite session counts for `k`. If its energy is the estimate of its rise, it has no
  loss, so it does not count.
- The cost takes the same share as the energy, so the energy in the battery has the average
  price of the window.
- Without the state of charge at both ends, or with too few sessions for `k`, the window
  keeps its charged energy.

`k` changes with the season. One `k` for each car is sufficient, because its error applies
only to the change of the state of charge, not to all charged energy of the window. The
correction makes the rate of a day change less from the day before. The average state of
charge of a day was not sufficient, because it is wrong on a day with a charge.

A day in the past sits in the center of its window, so a winter day keeps winter data. Five
rules limit a window:

- It ends today. The rate of a recent day can change for 14 more days.
- It starts at the installation date.
- It starts at the first distance of the odometer. A charge before it has no kilometers, so
  its energy would raise the rate.
- It stays inside the period of use of the car, so the rate of a new car holds no energy of
  the car before it.
- It needs 100 km and charged energy. Without them, the window widens by 14 days on each
  side, up to 42 days. A car that drives little can charge only once a month. A day between
  two such charges then gets the rate of these charges. Without a rate in the window of 42
  days, the day has no rate and no driving cost. The tooltips of the rates name the
  kilometers of such days.

A window with a session without a cost has an energy rate, but no cost rate. The selection
"all" adds the cars, each with its own windows.

The margin of 14 days is a compromise. A shorter margin fixes a recent rate sooner and
keeps the season more exactly. A longer margin gives a steadier rate. A shorter margin also
gives more days without a rate, because their window has less than 100 km. The wider window
applies only to such a day, so the other days keep the margin of 14 days.

### The balance of a month

A window reaches into the months around a day. So the days of a month hold the state of
charge at the ends of their windows, not at the ends of the month. A past calendar month
therefore scales its days to its balance:

```
energy of the month  =  charged energy  −  k  ×  (state of charge at its end − at the end of the month before)
cost of the month    =  charging cost   −  value of the energy in the battery at its end
                                        +  value of the energy in the battery at its start
value at an end      =  k  ×  state of charge  ×  price per kWh of the window there
```

A factor for the energy and a factor for the cost scale each day of the month. So the
month and the year hold the state of charge at their own ends, and the days still add up
to them. A week or a free range across the end of a month stays near its balance, but not
on it. The balance uses the same `k` as the correction of the windows. A `k` for each
charging power did not make a month more plausible.

Without the state of charge at both ends, a past month cannot know the change of the
battery. Many cars have no state of charge, or not for the early years. A window then
counts a charge before a long trip more than once, and a year can be several percent too
high. So the past months of a calendar year without the state of charge scale together,
with one factor, to their charged energy and their charging cost. The change of the
battery counts as zero. Over the many charges of these months, this is a small error. A
single month would be less exact than its windows, so the factor is one for the year.
The current year takes its past months, so its factors change at the end of each month.

A month keeps its days, with a factor of 1, in these cases:

- It is the current month, which has no end yet.
- It is not inside the period of use of the car.
- A day of the month has a distance without a rate. In a year, such a month stays out of
  the energy of the other months.
- A factor is outside 0.5 to 2. This hints at missing data, like a charge that a collector
  did not report.

The cost alone keeps its days with a session without a cost, or without a price at an
end. In a year, such a month stays out of the cost of the other months.

The days around the period need a summary and a detection too, so the car page builds them
before it shows the period (`Car::Report.pending_days`). A day reads its whole calendar
year for the factors of its months, and the windows of its days.

### Rejected designs

- An energy balance of each day alone with the battery content. The rate of a short day
  changed too much from day to day, and some days got a negative rate. The window uses the
  balance instead (see above). `car_range` cannot give the content, because kilometers to
  kWh needs the consumption, which is the result.
- One window for a period: the period plus the margin. The day columns of a month then had
  other windows than the tile and did not add up to it.
- A margin of 30 days. A recent rate changed for 30 days, and a winter month used November
  to March.
- A window that moves back near today to keep its length. The last 14 days then had the
  same window, and all columns of the current month were equal.
- `EUR/kWh` of the period × `kWh/100 km` of the window. A day that charges cheap PV energy
  then gets a low cost, also when the car drove on grid energy.
- A weight for each charge, so that it counts once in the overlapping windows. The driven
  energy of a long time then is the charged energy. But the weight depends on the distance
  alone, and it undoes the correction of the state of charge. A month with the state of
  charge was less exact than without the weights.

### Charging cost and driving cost

The charging cost is the money for the energy that went into the car in the period. The
driving cost is the money for the kilometers of the period. Both count the electricity
alone, so the user interface calls both "energy cost" (`sensors.car_charging_costs`,
`sensors.car_driving_costs`). The cards of the overview tell them apart by their titles.

An example: the car charges 50 kWh today for 10 EUR and drives 10 km. Its window holds
600 km and 30 EUR, so the rate is 5 EUR/100 km. The charging cost of today is 10 EUR, and
the driving cost is 10 km ÷ 100 × 5 EUR/100 km = 0.50 EUR. The rest stays in the battery
for the next days. Over a long period the two numbers come close. A cost is a sum, and a
rate is not. The user interface must never add a rate.

### Comparison with a combustion car

The comparison answers [#2407](https://github.com/solectrus/solectrus/issues/2407): what
did the car save against a combustion car that drives the same distance? A car compares
only with a fuel in its settings. With "all", each car needs a fuel, because otherwise the
comparison leaves out the distance of a car. `Car::Comparison` gives three columns:

- The car: the driving cost of its days.
- The car without the PV system: the same window, but each kWh of the wallbox costs the
  electricity price of its day. An offsite session keeps its cost.
- The combustion car: the distance × l/100 km × the fuel price of each day, and its tax.

The column without the PV system shows only on demand. A day counts only when it has a
cost in the two columns of the car and a fuel price, so the three columns drive the same
distance. The tax counts for each day in the period of use, because a tax is due for the
time.

The two columns of the EV split the cost of the driven energy by its sources: PV energy at
the lost feed-in tariff, grid energy at the electricity price, and the offsite sessions at
their paid price. Each day splits its energy and its cost by the sources of the charges in
its window, at the rate of the window and with the factors of its month
(`Car::Driving#sources`, `Car::EnergySources`). So the sources add up to the cost of the
energy. Without the PV system, the grid gives the PV energy too, and the offsite sessions
stay the same.

#### Payments

The payments of a car (table `car_payments`) hold everything that the car costs or earns,
for example its purchase, the rates of its lease, its insurance, its maintenance or the GHG
quota. Each payment has a category, which gives its direction, an income or an expense. The
amount of an expense can be negative: it is a refund, for example of the insurance, and
lowers the cost of its category. So a refund needs no category of its own. A loss of value
has no category, because it is known only after the sale.

The comparison counts the payments without the purchase, its financing, a subsidy and the
sale (`Car::Payment::COMPARED`). A combustion car has another price, so these payments
stay out, and the total of each column is "Running costs". The GHG quota, the vehicle tax
and the fees of the charging tariffs belong to the EV alone (`Car::Payment::ELECTRIC`). The
other categories are shared costs, for example the insurance and the maintenance
(`Car::Payment::SHARED`). The combustion car gets them at the same amount. So they change
no saving, but the bars show the real sizes of the costs.

A payment falls in the period of use of its car, like an offsite session. The purchase, the
down payment of a lease, a subsidy and the sale can lie outside, because the car is paid
before it comes, and the subsidy and the sale come after.

A compared payment spreads evenly over the days of its year in the period of use of the
car, like the tax, because these payments are due for a year. So the month of the payment
shows no peak. The payments are not in `cash_flows`, because each cash flow counts in the
amortization, and the car does not
([discussion #5796](https://github.com/orgs/solectrus/discussions/5796)).

The list of the payments (`/settings/car_payments`) remembers its filter, and a new payment
takes its car and its single category. So the next rate of a lease needs the date and the
amount alone.

#### Fuel prices

The fuel prices are in InfluxDB: one price for each week, in EUR/l.
`Sensor::Query::FuelPrices` reads them directly from InfluxDB, because they are few, and
`Car::FuelPrices` caches them. A price holds until the next one. The fields are
`Fuel:price_petrol`, `Fuel:price_diesel` and `Fuel:price_lpg`. They are fixed, so they need
no configuration. The prices are in EUR, so the comparison needs `CURRENCY=EUR`. With
another currency, the fuel prices count as missing.

Without fuel prices, the comparison is not available (`Car::Comparison.available?`). The
navigation and the settings then hide the comparison, the combustion car of each car and
the payments, and their addresses lead away.

#### The pages

The car page shows the savings for each timeframe but the live view, in a bar below the
cards. The whole bar is the cost of the combustion car, so the running costs of the EV and
the savings stand side by side. The bar links to the comparison of the same timeframe.
Without a comparison, it is an empty track, and its tooltip names the reason.

The comparison page (`/cars/savings`) takes each timeframe of whole days. Like the car page,
it is open to everyone. Above the figures, warnings name what the data lacks
(`Car::ComparisonGaps`), for example offsite sessions that wait for a confirmation or a
wallbox without the power splitter. Each column shows its calculation step by step. A
chart gives the cost of the periods of the timeframe (`Car::ComparisonChart`), and another
chart the cost per 100 km of each week (`Car::ComparisonRateChart`). The tax and the
payments do not count in the weekly chart, because they spread evenly over the days, and a
week with a short distance would jump.

These rules of the page are decisions:

- The page shows no ratio of the costs, as a factor or a percentage. The comparison holds
  only a part of the costs of a car, without the purchase. A cost that both cars share
  does not change a difference, but it changes a ratio. When the EV costs almost nothing,
  a small change of its cost also makes a ratio jump.
- The price row shows the lowest and the highest fuel price of the timeframe, not an
  average. An average beside the fuel would look like one price for the whole timeframe.
- A number links to a drill-down only where the target shows the same number
  (`Car::ComparisonLinks`). The payments are the exception: they link to the list of the
  payments, which shows each payment in full, also when the comparison has only a part of
  it. The row of the combustion car has no link, because it holds the tax too.

## Charts

| Chart                                                                              | Class           | Columns                                              |
| ---------------------------------------------------------------------------------- | --------------- | ---------------------------------------------------- |
| `car_charging`, `car_charging_costs`                                               | `CarSessions`   | PV, grid and offsite, of all selected cars together  |
| `car_driving_energy`, `car_driving_costs`, `car_consumption_rate`, `car_cost_rate` | `CarDriving`    | sum of the days of the column, a rate ÷ the distance |
| `car_distance`                                                                     | `CarDistance`   | distance of the column, a part for each car          |
| `car_battery_soc`                                                                  | `CarBatterySoc` | min and max of the column, one car                   |
| `car_max_range`                                                                    | `CarMaxRange`   | average of the column, one car                       |

A week and a month have a column for each day, a year for each month, and all for each
year. The live view and a day have no chart. Each chart belongs to a column of the
overview, the charging or the driving (`Car::Section::CHARTS`). The chart menu offers no
chart that the selected cars cannot draw, like the distance of a car without an odometer.
Such a chart stays in the address, and the page shows the default chart. So the chart comes
back with the next timeframe.

The values of two cars do not add up for the state of charge and the ranges, so these
charts need one selected car (`Sensor::Chart::Concerns::OneCar`). The rates stay one
column in "all", for the same reason. In "all" of several cars, the sums stack a part of
each column for each car.

A rate column without a day with a rate has a gap. The distance has no split by energy
source, because the source of the energy belongs to the charge, not to the drive.

Each chart shows its insights below it (`Car::Insights::Component`). A rate and the maximum
range also name the best and the worst period of the same kind (`Car::Spans`). These rules
for the best and the worst period are decisions:

- Only a day, a week, a month or a year has periods of its kind. The whole time, a relative
  timeframe and a range of dates name no best and no worst period.
- A period counts only when the cars were in use on each of its days. A month in which a
  car started gives a value of a few days. The shown period always counts.
- The best and the worst period need three periods with a value. Fewer periods say nothing.
- They read each day of the whole time. Before the car page shows a calendar period, it
  therefore builds the missing daily summaries of the whole time.

## The car page

The navigation shows `/cars` when at least one car is configured and `Setting.enable_car`
is true, which is the default. Without a car, the car page and the settings of the cars stay
away, and the detection still writes the sessions of a wallbox without a car. Without a
sponsorship, the page shows an offer (feature `:car`). The page shows its numbers when a
car has an odometer or a state of charge.

The car page has two levels. The live view and the overview of a period are the top. Below
the overview are the list of the charging sessions and the list of the places. A third level
does not exist. The maps fill the window over their list, and a filter narrows a list in
place, so neither adds a level.

The car page has no hours view, because its numbers come from full days. An hours
timeframe goes to today. The list of the charging sessions keeps the hours view.

### The selection of the car

With more than one car, a select chooses one car or "all". The address has the car in front
of the page (`/cars/2/2025`, `/cars/2/car_charging/2025`), and the lists do the same. Each
link of the car page keeps the car, and a link to another page does not get it. Without the
car in the address, the page shows "all".

A timeframe offers only the cars in use in it. The select offers "all" also with one car in
the timeframe, because "all" adds the guest sessions to that car. A car that the page does
not offer redirects to "all". The chart menu never names a car, because the select above it
chooses the car.

When the wallbox has a guest session, the select also offers the guest
(`/cars/guest/2025`), also in a period without a guest session. The guest has no car, so the
page shows its charging alone and has no driving. An installation with one car and without
a guest session has no select.

The selection "all" is the sum of the cars and of the guest, and not the sum of the wallbox.
A session that is not assigned counts for no car, because no car is known to have charged
that energy. When the period has such a session, the link to the charging sessions names
their number. A number that is too small without a reason is the one error this page must
not make.

### The live view

The live view shows each car in use today, so it has no select and selects no car. A car in
its address redirects to `/cars/now`. When another timeframe has one car in use, the link
from the live view to it selects that car.

Each car has a card of its own (`Car::LiveCard::Component`):

- The age of its latest reading. The age is necessary, because a car sensor holds its value
  at any age.
- The range, and the state of charge on the scale from 0 to the maximum range.
- For the admin, the latest position on a map (see [Location](#location)).
- The plug of the car (`car_connected_<n>`), with the charging power while the car charges.
  A car away from home is not at the wallbox, but can be connected to any other charger, so
  its card names the plug and not the wallbox. For a lone car without a plug of its own, the
  plug of the wallbox counts only at home.
- The odometer.

Only the car at the wallbox shows the power of the wallbox (`Car::Live`). When the wallbox
charges and no car shows its power, the live view adds a card of the wallbox. With the
plugs of the cars, a guest charges, so the card names the guest. Without them, the card
names the wallbox.

A car without a range sensor gets an estimate of its range (`Car::RangeEstimate`), and the
live view names it an estimate. The charged energy of a percentage point (`k`, see above)
gives a distance at the energy per km of the recent days (`Car::Driving#rate`). Both are
energy at the charger, so the loss of a charge cancels out, and the estimate needs no
capacity. The energy per km also holds the energy that the car uses while it stands. So the
estimate is lower than the range that a car reports, and the difference grows when the car
drives less per day. The estimate does not correct this, because the energy that a car uses
while it stands is not known.

### The overview

The overview has two cards: the charging and the driving (`Car::PeriodOverview::Component`).
Below them, a bar shows the savings against a combustion car (see
[The pages](#the-pages)). A week, a month, a year and the whole time show one chart beside
the cards. A day shows its timeline in the place of the chart (see [The day](#the-day)).

A click on a figure loads its chart, and the address keeps the chart, for example
`/cars/2/car_cost_rate/2025`. Without a chart in the address, the page shows the first chart
of the driving, or of the charging when the period has no drive.

The card of the charging shows the charged energy and its sources, PV, grid and offsite,
each with its cost. The card of the driving shows the distance, its energy cost and the two
rates. A selected car without an odometer has no driving, and neither has the guest. The
page then shows the card of the charging alone, without the bar of the savings.

These rules are decisions:

- The figures show no comparison with the previous month or year. Only the insights show
  them.
- The values show no red, because red marks a low cost as bad. Only a loss against a
  combustion car is red, because it is a real loss.
- The overview has no ring. The ring of the distance of one car was always full and told
  nothing.
- The card of the charging keeps its figures with 0 when the numbers leave out all its
  sessions, because its link names these sessions.

### The day

The overview of a day shows the timeline of the day in the place of the chart
(`Car::DayTimeline::Component`). Its axis is the local day from 0:00 to 24:00, so a day of a
change of the clock has 23 or 25 hours on the same width. The running day ends at now.

The timeline of a car has three rows:

- The charging sessions, and the times in which the car was plugged in but did not charge.
  A session at the wallbox shows its power over time, split into PV and grid. All sessions
  of a day use one scale, so a slow charge stays low beside a fast one. An offsite session,
  or a session without the curve, stacks the shares of its sources, because parts side by
  side read as one after the other in time.
- The drives (see [The drives](#the-drives)).
- The state of charge, as a line through its readings (see
  [The line of the state of charge](#the-line-of-the-state-of-charge)).

On "all", each car has a timeline of its own. The guest has a timeline with its charging
alone. The tooltip of a bar names what the car did, its time, its place and its numbers.
The admin opens the form of an offsite session with a click on its bar.

A session over midnight shows on both days, each day with its part, and on the next day a
note says that it counts for the day on which it started. An offsite session without an end
has no time of its own, so the readings of its car give it
(`Car::DayTimeline::OffsiteEstimate`): first a rise of the state of charge, else the time
plugged in, else the rest of the day. The timeline marks this time as an estimate.

A session at the wallbox that pauses while the car stays plugged in, for example until the
cheap tariff of the night, stays one bar with its pause in it. So its energy and its cost
stand once.

The plug of a car tells the times in which it was plugged in, without the time of a session
and of a drive. A car reports late that it was unplugged, so a drive ends the time plugged
in. The plug of the wallbox does not tell which car is plugged in, so it gives no time
plugged in.

Driving never overlaps charging or a time plugged in. A drive gives way to a session that
the car recorded, because the table holds its time. A session with an estimated time gives
way to a drive, because the odometer tells the drive.

The curves are those of the daily build (`ChargingSession::Curves`). The timeline takes the
readings of a car at their own time, not the 5-minute mean. Otherwise a car that reports
when it leaves would start its drive up to 5 minutes late. The cloud of a car can send its
last known state again and again while the car is offline, also while it drives or charges.
These readings are no readings, so the timeline leaves them out
(`Car::DayTimeline::StaleReadings`), and the time counts as a gap.

#### The drives

No table holds the drives, so `Car::DayTimeline::Drives` finds them in the readings of the
odometer and of the state of charge. Its comment holds the rules. A car reports at a pace of
its own, and the collectors differ too. Some write the odometer while the car drives.
Others write the odometer of the start until the car stops, so its increase comes after the
drive. These are the principles of the rules:

- An increase of the odometer is a drive from the reading before it to the reading with it.
  After a long gap, that reading is only the earliest start.
- The state of charge falls while the car drives, also when the odometer stands still. So
  where it falls, it tells the start better. A fall of one point over a long time is noise.
- The increase of the odometer ends the drive, because a car can report its state of charge
  while it drives. If the state of charge stood still before the increase, the car stood
  there, and the odometer came late.
- A short pause joins two drives, because the state of charge can stand still for a reading
  while the car drives. A charge or a visit in the pause keeps the drives apart, because the
  car stood there. Two readings of the odometer without a rise over some minutes do the
  same, also where the stop was too short for a visit. A car reports late, so a charge or a
  visit that starts shortly before the increase ends the drive.
- A car can report the last part of a drive after the arrival. Its distance belongs to the
  drive that arrived. A car does not drive while it charges, so this applies to each
  increase within a charge.
- A very short drive is no drive, like a move of the car in front of the house. This rule
  applies after the drives join, so the short parts of a slow drive stay in it.
- A wrong reading of the odometer adds no drive, like in the distance of the day.

The distance of a drive must fit its time. A very slow drive is only the window between two
readings, in which a short drive took place. A very fast drive starts too late. Some cars
report only when they park or wake up, so a drive can fill the whole time between two
readings. A drive without a reading within it, or without a start, therefore starts at an
assumed speed before its end. A bar whose readings leave its time open has a jagged edge,
and its tooltip says why.

On the running day, a car that reports its odometer only when it stops tells nothing of a
drive that still runs. A fall of the state of charge up to now, without an increase of the
odometer, is therefore a drive up to now, without a distance.

A car reports its place late, so a visit can last until the car arrives at the next place,
and only the start of a visit is sure. A drive therefore starts at the last place where the
car arrived before it, and it ends at the next visit. Only a visit that starts between the
start of the drive before and the start of the drive after counts, so a stop without a
visit between two drives leaves both open there. A stop becomes a visit only after some
time, so on the running day, the last drive without a visit at its goal ends at the place
where the car stands now.

#### The line of the state of charge

`Car::DayTimeline::SocLine` draws the line from the readings of the state of charge. Its
comment holds the rules:

- Between two close readings, the line holds the first value and steps at the second, like
  the chart of the state of charge.
- Between two readings far apart, a step at the second reading comes too late. A car that
  charged at noon and reported in the evening would rise in the evening. So a rise follows
  the charging sessions between the two readings, and a fall follows the drives.
- If no charging session and no drive explain the change, nothing tells when the value
  changed. The line is then a slope from one reading to the next, marked as unknown.

A car reports whole percent, so a charge or a drive is a stair of small steps. The timeline
draws a line through the middle of the steps (`Car::DayTimeline::SocCurve`). A longer hold
stays flat, like a parked car. The tooltips keep the readings.

### The lists

The list of the charging sessions and the list of the places are pages below the overview.
Each has a timeframe and a select of the car, and its way back leads to the overview in the
same timeframe and with the same car. On a phone, the overview opens both lists in a sheet
(see the section "Sheets with pages" in [docs/ui.md](ui.md)).

- The charging sessions (`/cars/2/charging_sessions/wallbox/2025`, see [The list](#the-list)).
  The link from the wallbox on the power balance opens the list too.
- The places (`/cars/2/places/2025`) and the visits (`/cars/2/visits/2025`), see
  [Location](#location). Only a car with a location has places, so without one the overview
  has no link to them.

## Visitors

A visitor without the admin login sees the car page, but not what tells where the cars are
or when someone is away from home:

- The name and the short name of a car are personal data. A visitor sees the default name
  ("Car 2").
- Only the admin sees today and yesterday (`Car::AdminOnlyDays`). Such a day shows when the
  cars drove and charged. A visitor gets a note with the login. An older day stays public,
  so a visitor of the demo sees the page some days back.
- A longer period, like a week, ends with the day before yesterday for a visitor: its
  figures, its charts, its insights, the savings and the Top 10 of a car sensor. Their
  amounts tell the same as their times. A note says so, with the login, so someone who only
  forgot to log in sees why the latest days are missing.
- The list of the charging sessions leaves out the sessions of such a day, also in its sums.
  A large offsite charge tells that the car is far away. A note names the hidden days
  whenever the list holds them, also without a session there, so the note tells nothing
  itself.
- A visitor sees no session to review, no address of an offsite session and no form.
- The location is the admin's alone (see [Location](#location)).

The live view stays public, because it shows no time of a drive. The state of charge of a
car on the power balance stays public too.

## Location

`car_latitude_<n>` and `car_longitude_<n>` give the location of a car. The location is
personal data, so only the admin sees it. The definitions declare `admin_only`:

- A visitor gets no value of the sensors.
- The lists of the places and of the visits, the map of the places and the tooltips of the
  places ask a visitor to log in. The overview still shows a visitor the link to the places.
- The live view shows a visitor a sample map of a made-up place, with the login.
- The MCP server does not offer the sensors.

A position needs the latitude and the longitude. InfluxDB has no type for a point, so a
collector writes two fields, at best in one point. Each coordinate is a state that holds
until its next reading, so the two can also come from separate messages at different times.

For the admin, the card of each car in the live view shows its latest position on a map
(`Car::Location::Component`). The map names the place, or else the town near the position.
A car that drove away from its latest position is on the road.

The list of the places shows the places of the selected cars, the most visited place first.
A switch shows the visits instead. The map of the places lies over the list, with the
timeframe and the car of the list. A chart beside the numbers of the car page was too small
for a map, and a page of its own added a third level.

The map shows a circle for each place of the selected cars. The area of a circle shows the
share of the time that the cars spent at that place. Each point has one color, also for a
single car, because the color of a car marks the car and not its places. One circle for
each car and place was the other choice, but then the visits in the tooltip of a car did
not match the list of the visits of all cars.

The map uses MapLibre and the vector tiles of OpenFreeMap. These tiles need no key, have a
dark style and have the names in each language.

### Visits

A visit lasts from the arrival of a car at a place to its departure. The visits are a step
of the daily build (table `place_visits`, `Place::VisitDetection`, see
[When the detection runs](#when-the-detection-runs)). "Delete the summaries" also deletes
the visits, and the places keep their names.

The step reads the positions of each car, and a position lasts until the car drives away
(see [Sensors](#sensors)). A night at home is therefore one visit, also when the car sends
nothing. A parked car reports slightly different positions, so the step joins each
position near the stop before into this stop.

Each stop has a limit:

- A stop at no place and shorter than its limit gets no place, for example a traffic light.
- A visit shorter than its limit is left out, for example a drive past the home.
- Two visits at one place make one visit when less time than the limit lies between them.

A drive past a place has one reading there and lasts one interval of the readings. A visit
has two readings and lasts two intervals. The limit is therefore 1.5 intervals, within a
lower and an upper bound. The interval comes from the readings at the stop, so it follows
the user when the car reports more often. A car that reports only at the arrival sends one
reading at a stop, which gives no interval. Its stop then gets the lower bound.

A visit at a known place has a lower bound that is shorter, for example a stop at a shop. A
traffic light is rarely near a place. A new place needs the longer bound, and so does the
time between two visits that join. [The rules](#the-rules) give the values.

The step cuts the visits at midnight, like a daily summary. The list of the visits joins
these rows again and shows a visit that is still going on without an end.

### Places

The table `places` holds the places where the cars stood. A stop that reaches its limit gets
a place when no place is near. Only the daily build makes a place, because a car on the road
must not leave places behind. The user gives a place a name, for example "Home". Without
it, a place shows its district and its town. The list of the places is a page of the
settings.

A place has labels (`Place::LABELS`). The labels are a string array, so a new label needs no
migration. The label "Home" marks the place of the wallbox, and only one place has it. The
assignment of the charging sessions and the proposals of the offsite sessions use it.

Both read home only at a position of a car. A position lasts until the next reading, so a
parked car also has a position on a day without a reading. A new home therefore removes the
summaries of each car with a location, from its first position in InfluxDB to the end of its
period of use (`Place::HomeChange`). Without such a car, the summaries stay. If InfluxDB
cannot give the first position, all summaries go.

A place stays when its visits go, also after "Delete the summaries". So a place from wrong
positions stays after the user corrects the positions in InfluxDB. The list marks a place
without a visit as never visited, and its page offers its deletion alone
(`Place#deletable?`). A place with visits stays, because its days would lose their visits.
Home stays too, because a new home builds the days again.

### Address

The address comes from Nominatim, the geocoder of OpenStreetMap (`Place::Nominatim`). The
position of the address of an offsite session comes from it too. Its
[usage policy](https://operations.osmfoundation.org/policies/nominatim/) allows one request
per second and no periodic requests. So SOLECTRUS asks it only when the user asks for a
place: the map of a car in the live view, the form or the tooltip of a place, and the form
of an offsite session.

A place asks once and keeps the answer. A location without a place gets no new place. The
build and the list of the sessions ask nothing, because the backfill asks for each charge
of the history. The usage policy forbids an autocomplete, so the form asks nothing while the
user types. The policy also requires a cache, which keeps an answer for a week.

`NOMINATIM_URL` selects another server of Nominatim, for example one of your own. The usage
policy requires this switch without a software update. If `NOMINATIM_URL` is set but empty,
SOLECTRUS sends no location to Nominatim. A place and a car on the road then show no town.

The request sends a User-Agent with the version of the app and the word "self-hosted". All
installations send the same User-Agent, so the word tells the operators of Nominatim that
each IP address is a separate installation.

## The rules

`Car::Rules` holds the values of the rules for the reports of a car, its places and visits,
its drives and its charges. The classes that apply a rule refer to it there. If you change a
value, the result of a step of the daily build changes. You must then increase the `VERSION`
of that step, so that the build runs again.

| Area    | Rule                                                               | Value    | Constant                          |
| ------- | ------------------------------------------------------------------ | -------- | --------------------------------- |
| Reports | A car reports a change of its position or connection late by       | 15 min   | `REPORT_LAG`                      |
| Reports | The report of a drive can come after an arrival by                 | 20 min   | `ARRIVAL`                         |
| Reports | A reading of the state of charge counts after a charge for         | 2 h      | `READING_DISTANCE`                |
| Reports | The state of charge can come after the odometer by                 | 5 min    | `SOC_LAG`                         |
| Reports | A change of the state of charge is noise up to                     | 1 point  | `SOC_NOISE`                       |
| Reports | A rise of the state of charge at the wallbox is noise below        | 1 point  | `MIN_SOC_RISE`                    |
| Places  | A position belongs to a place within                               | 100 m    | `PLACE_RADIUS`                    |
| Places  | A stop makes a new place from                                      | 30 min   | `MIN_STAY`                        |
| Places  | A stop at a known place makes a visit from                         | 15 min   | `MIN_KNOWN_STAY`                  |
| Places  | The limit of a stop in intervals of the readings                   | 1.5      | `STAY_INTERVALS`                  |
| Places  | The limit of a stop is at most                                     | 3 h      | `MAX_STAY_LIMIT`                  |
| Places  | A rise of the odometer after a position ends it from more than     | 1 km     | `POSITION_MOVE`                   |
| Places  | A visit belongs to a drive up to this before or after it           | 1 h      | `VISIT_REACH`                     |
| Drives  | A gap before a rise of the odometer gives no start from more than  | 1 h      | `MAX_DRIVE_GAP`                   |
| Drives  | A gap before a rise of the odometer gives an estimated start up to | 3 h      | `MAX_ESTIMATED_GAP`               |
| Drives  | A pause joins two drives up to                                     | 30 min   | `MAX_DRIVE_PAUSE`                 |
| Drives  | A fall of 1 point is no drive over more than                       | 30 min   | `SOC_NOISE_TIME`                  |
| Drives  | An odometer without a rise in a pause is a stop from               | 10 min   | `MIN_STOP`                        |
| Drives  | A drive without a start is assumed at an average speed up to       | 80 km/h  | `MAX_ASSUMED_SPEED`               |
| Drives  | A drive needs a distance of                                        | 0.5 km   | `MIN_DRIVE_DISTANCE`              |
| Drives  | A drive is a short drive in a window of the readings below         | 5 km/h   | `MIN_DRIVE_SPEED`                 |
| Drives  | … if it lasts longer than                                          | 20 min   | `MIN_WINDOW`                      |
| Drives  | A drive starts too late above                                      | 150 km/h | `MAX_DRIVE_SPEED`                 |
| Drives  | The live view shows a drive at a fall within 1 h of more than      | 3 points | `DRIVE_DRAIN`, `DRIVE_DRAIN_TIME` |
| Charges | A session at the wallbox needs                                     | 0.1 kWh  | `MIN_SESSION_KWH`                 |
| Charges | A gap of the wallbox ends no session up to                         | 15 min   | `MAX_SESSION_GAP`                 |
| Charges | A charge with a slow rise keeps one state of charge up to          | 1 h      | `MAX_CHARGE_PAUSE`                |
| Charges | An offsite proposal needs a rise of                                | 5 points | `MIN_OFFSITE_RISE`                |
| Charges | … or, with a connection, a rise of                                 | 3 points | `MIN_CONNECTED_RISE`              |
| Charges | A step of a drive beside a charge holds no charge of its own up to | 30 min   | `MAX_CHARGE_EDGE`                 |
| Charges | An offsite session blocks proposals around it for                  | 1 h      | `PROPOSAL_MARGIN`                 |

## MCP

The numbered sensors `car_battery_soc_<n>`, `car_odometer_<n>`, `car_range_<n>`,
`car_max_range_<n>` and `car_connected_<n>` reach MCP as all sensors do. The location of a
car does not reach MCP (see [Location](#location)).

`car_odometer_<n>` has two meanings. A live value and a curve give the odometer reading. A
total, a period and a ranking give the distance driven. Its description says both.

The charts of the car page have no number. The sensor tools have no selection of a car, so
most of these charts get no sensor tool, and `list_sensors` does not list them.
`car_distance` is the exception: it adds up the cars, so `get_ranking` ranks it. A client
that asks for a role like `car_battery_soc` gets no values, but a rejection that names the
numbered sensors of the cars, for example `car_battery_soc_1 (Model Y)`. This matters
because `car_battery_soc` was a sensor with values before cars had numbers.

`get_car_costs` gives the figures of the car page for a timeframe of whole days: the
distance, the charging with its sources, and the driving with its rates per 100 km. It
takes the number of one car. Without it, it covers all cars like the selection "all" of the
page, so it counts the guest sessions too. The response names the guest sessions and the
sessions of no car separately. Only an installation with a car offers the tool, because
each tool costs every MCP session its description.

The figures read the summaries of whole years around the timeframe (see
[Rates and driving cost](#rates-and-driving-cost)). Like the other tools, it builds the
missing and the stale summaries of these days, but at most a month of them in one call. A
build of more days takes too long for an MCP call. Then the tool stops and names the days,
and the car page of the same timeframe builds them. It does not answer with a note like
the other tools: a missing day changes the rates of the days around it, so each figure is
wrong and not only short.

With fuel prices, the response also holds the comparison with a combustion car (see
[Comparison with a combustion car](#comparison-with-a-combustion-car)). It gives the three
columns of the comparison page with their totals and their costs per 100 km, and the savings
with and without the PV system. Each gap of `Car::ComparisonGaps` becomes a sentence. If a car
has no combustion car in the settings, or the timeframe has no distance to compare, a note
says why. Without fuel prices, the response says nothing about the comparison, because the
page and its settings are hidden then too.

The amounts are the exact amounts of `Car::Comparison`, rounded by their unit like all MCP
values. The page rounds them with `Car::ComparisonAmounts` to whole units for large amounts,
and a part can take the rest of its rounded sum. So an amount can differ from the page by
about one unit. The costs per 100 km are the same. The rule of the page holds here too:
the description tells the client to give differences and no ratio.
