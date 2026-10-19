# Cars

How SOLECTRUS shows electric cars: their state, the distance they drive, the energy they
charge and what the driving costs. SOLECTRUS supports up to five cars. This document
describes what exists, and [cars-todo.md](cars-todo.md) holds the plan. Change this
document in the same pull request as the code. A design decision that is in neither file is
lost.

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

| Class                               | Job                                                               |
| ----------------------------------- | ----------------------------------------------------------------- |
| `Car`                               | a car: number, name, color, period of use, `Car.configured`       |
| `Car::PeriodChange`                 | what follows when the period of use of a car changes              |
| `Sensor::Cars`                      | the numbers and the sensor names of the cars, without a database  |
| `ChargingSession`                   | a charge of a car, at the wallbox or offsite                      |
| `ChargingSession::Sums`             | the sums of a set of sessions: count, energy, cost, PV share      |
| `ChargingSession::Detection`        | finds the wallbox sessions in the power curve of a day            |
| `ChargingSession::OffsiteDetection` | proposes offsite sessions from the state of charge of a day       |
| `ChargingSession::AddressLookup`    | the position of the address of an offsite session, from Nominatim |
| `Car::Ledger`                       | the car days of a date range: distance and session sums           |
| `Car::Driving`                      | the rates of each day from its window                             |
| `Car::Report`                       | the numbers of a timeframe, for the page and for its charts       |
| `Car::Spans`                        | the lowest and the highest rate of the periods of one kind        |
| `Car::Live`                         | the live values of the wallbox and of each car                    |
| `CarSelection`                      | the selected car (`/cars/2/…`) on the car page and in the lists   |
| `Place`, `Place::VisitDetection`    | the places where the cars stood, and the visits there             |

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
variables is enough for a number. A variable with a number above `MAX` is ignored with a
warning.

A car variable without a number is the variable of car 1, so an installation with one car
needs no number. `INFLUX_SENSOR_CAR_BATTERY_SOC` is from the time before cars had numbers.
No variable without a number is deprecated. If both are set, the numbered variable wins
with a warning.

The table `cars` holds what the environment cannot:

| Column         | Meaning                            | NULL means                                     |
| -------------- | ---------------------------------- | ---------------------------------------------- |
| `id`           | the number, no sequence            | –                                              |
| `name`         | the name of the car                | the name comes from I18n ("Car 2")             |
| `short_name`   | at most five characters            | – (required, a new car takes its number)       |
| `active_from`  | the first day of use               | – (required, by default the installation date) |
| `active_until` | the last day of use                | the car is in use                              |
| `color`        | a hex code like `#3b82f6`          | the default color (sky blue)                   |
| `battery_kwh`  | the usable capacity of the battery | no capacity                                    |

`Car.configured` gives the cars of the configured numbers. It creates a missing car on the
first request that needs one, so a user with one car has nothing to do. It is not part of
`Sensor::Config`, because a database write at configuration time couples the two layers.

The number of a car never changes, because the daily values store its history under the
sensor name with the number. SOLECTRUS never removes a car, so a sold car keeps its number
and its history. The car management page (`/settings/cars`) edits the columns. It adds no
car, because a configured number gets its car by itself.

### Name and color

The name of a car sensor is the car name plus the role: "Model Y (SOC)". The short name
stands where a long name takes too much space, for example in the button of the car select.
A car without a name shows its short name in each place. A new car has its number as short
name, which says less than the default name "Car 2", so it shows the default name.

The name and the short name of a car are personal data, so only the admin sees them. A
guest sees "Car 2" in each place.

The color of a car marks it where cars stand side by side: the badge of a charging session
and the select of the car. In the charts of all cars, it tints the parts of the distance
and the driving cost (see [Charts](#charts)). The sensors of a car keep their own colors,
because each sensor has its own meaning.

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
an accepted offsite session of the car outside.

A change of the variable of a sensor with daily values calls `Summary.reset!` and replaces
its history. The car management page says this.

## Sensors

| Sensor                 | Variable                            | Daily summary       | Meaning                      |
| ---------------------- | ----------------------------------- | ------------------- | ---------------------------- |
| `car_battery_soc_<n>`  | `INFLUX_SENSOR_CAR_BATTERY_SOC_<n>` | `min`, `max`, `avg` | state of charge (%)          |
| `car_odometer_<n>`     | `INFLUX_SENSOR_CAR_ODOMETER_<n>`    | `sum`               | odometer (km)                |
| `car_range_<n>`        | `INFLUX_SENSOR_CAR_RANGE_<n>`       | `avg`               | remaining range (km)         |
| `car_connected_<n>`    | `INFLUX_SENSOR_CAR_CONNECTED_<n>`   | none                | car plugged in (boolean)     |
| `car_latitude_<n>`     | `INFLUX_SENSOR_CAR_LATITUDE_<n>`    | none                | latitude (degrees)           |
| `car_longitude_<n>`    | `INFLUX_SENSOR_CAR_LONGITUDE_<n>`   | none                | longitude (degrees)          |
| `car_max_range_<n>`    | none, calculated                    | `avg`               | range at a full battery (km) |
| `car_charging`         | none, chart only                    | none                | charged energy               |
| `car_charging_costs`   | none, chart only                    | none                | charging cost                |
| `car_consumption_rate` | none, chart only                    | none                | `kWh/100 km`                 |
| `car_cost_rate`        | none, chart only                    | none                | `EUR/100 km`                 |
| `car_driving_costs`    | none, chart only                    | none                | driving cost                 |
| `car_battery_soc`      | none, chart only                    | none                | state of charge of one car   |
| `car_distance`         | none, chart only                    | none                | distance of the cars         |
| `car_range`            | none, chart only                    | none                | range of one car             |
| `car_max_range`        | none, chart only                    | none                | max. range of one car        |

The registry makes the seven sensors of a car for each number up to `MAX`, and
`Sensor::Config` removes a number without a configuration. These sensors hold the data.
The car page shows only the chart-only sensors, which have no number. The select above the
chart chooses the car, and the chart menu chooses the chart. The chart menu offers no chart
that stays empty for the selected cars, and an address of such a chart goes to the default
chart.

All car sensors need the permission `:car`. The rates and the driving cost exist when a car
has an odometer, because the energy and the cost can come from the offsite sessions alone.

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
aggregation `sum`. The odometer is also a state: a collector writes it when it changes, so
a reading holds until the next one. A day can therefore have one reading or none. The odometer
at a midnight is the last reading before it (`Influx::DailyDiffs`). A day without a reading
has a distance of 0. The daily values add up exactly: the sum of a range is the odometer at
its end minus the odometer at its start. A day before the first reading has no value, so an
odometer that comes after the installation gives no distance of 0 for the time before it.

If the collector was down while the car drove, the next reading shows the distance of the
gap. This distance goes to the day of that reading. A later reading never changes the
distance of an earlier day.

A wrong reading of the odometer adds its jump to the distance of a day. Some collectors send
0 while the car is offline, so the jump back is the full odometer. `Sensor::MeterReadings`
therefore leaves out a reading of 0 or less and a reading more than 1 km below the reading
before it. A reading that the next reading confirms stays, because then the odometer
changed for good, for example after a new source. The day of this change gets no distance,
because a daily distance is never negative.

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
energy of each day stays on its day.

### The list

The page `/cars/charging_sessions` lists the sessions. Only the admin can open it. It
belongs to the car page: the badges of the charging card and an item of the main
navigation open it, and a back link opens the car page in the timeframe of the list. When
the settings switch the car page off, or no car is configured, the list goes to the start
page. Without a
sponsorship, it goes to the offer of the car page.

The list has a tab for each kind and a filter of the car in the header: one car, "all", for
the wallbox also "not assigned" and the guests, and for offsite the proposals.
`CarSelection` gives the filter, like the select of the car page, so it offers only the
cars in use in the timeframe. Without a wallbox, the tab of the wallbox sessions shows only
while sessions of an earlier wallbox exist.

The list of the offsite sessions has a second view, a map. The menu of the filter switches
the view, and the address keeps it as the segment `map` after the timeframe, for example
`/cars/1/charging_sessions/offsite/2025/map`, so a change of the timeframe or the filter keeps
it. The wallbox sessions have no map, so their address with `map` leads to their list. The sessions in one cell of about 100 m share a circle, and the area of the circle
shows the share of the energy. A circle loads its tooltip when the pointer rests on it. A
note on the map counts the sessions without a position. The wallbox sessions have no map,
because they all share one place.

The user changes the car, the guest mark and the note of a wallbox session. The detection
writes its time, energy and cost, so the form shows them read-only. A new session is always
`offsite`, because a guest charge that no wallbox measured has no energy and no cost. The
list deletes only an offsite session.

The list shows a proposal with its estimate, but its sums leave it out. A save in the form
accepts a proposal, so the form needs the cost. The user can also dismiss a proposal.
The filter of the proposals has no sums. Instead, a row above the list dismisses all
proposals of the timeframe at once, for a time without receipts
([#6021](https://github.com/solectrus/solectrus/issues/6021)). It dismisses only the
proposals that the list showed, so a proposal of a later build stays.

The form shows the loss of a charge: 1 − rise ÷ 100 × `battery_kwh` ÷ `kwh`. A loss in each
row added no value to the list. The loss needs a rise of 20 points or more, because the
state of charge has whole percents.

The list shows a charge over midnight in one row (`ChargingSession.joined`), and a count
counts it once. The data keeps a session for each day, so the daily sums and the charts
stay exact. The list keeps the hours view, because the sessions of the last 24 hours are a
useful list.

The detection writes the end of the latest bucket with power. So a charge that goes on gets
an end and a state of charge at the end that change with each build. The list shows such a
session as ongoing: its start alone ("since 12:20"), the state of charge at its start, a
mark and no loss. A session is ongoing when it reaches the latest build of today within
the gap of the detection, and the wallbox reports power now. The table does not store this
state, like for an ongoing visit (see [Visits](#visits)).

### The detection

`ChargingSession::Detection` finds the wallbox sessions in the wallbox curve of a day:

- A session is a continuous period with `wallbox_power > 0`, found on the 5-minute means.
  A gap of 15 minutes or less does not end it, because load management and PV surplus
  control make such gaps.
- `wallbox_car_connected` bridges a longer gap, but it never moves an end. Otherwise a
  charge before the sensor reports the connection loses its energy.
- A 5-minute bucket without a reading is no data, not 0 W. A collector can fail for an
  hour while the car charges. Such a gap does not end a session. A session also reaches
  across a gap at each end, to the next bucket with data. The daily sum integrates across
  the gap from the last value to the next one, so the sessions keep the energy of the day.
  The buckets without a reading come from a query of their own, because the curve holds
  the buckets with power alone.
- A session needs 0.1 kWh at least, because many wallboxes report a standby power.
- The energy comes from the integral of the power, like the daily sum. The grid share comes
  from `wallbox_power_grid` in the same way. The power splitter writes one value in the
  middle of each cycle of 5 minutes. So the integral of the grid share reaches one cycle
  beyond each end of the session, within its day. Otherwise the session loses the grid
  share of its first and its last cycle, which the daily sum holds.
- The grid share costs the electricity price and the PV share the feed-in price of the day.
  Without the power splitter, `kwh_grid` stays NULL, and the full energy gets the
  electricity price. Without a price, `cost` stays NULL, because zero is a wrong number.
  The car page then names the missing price.
- The state of charge at the start is the last reading before it. The state at the end is
  the highest reading up to 2 hours after it, because a car that is offline during the
  charge reports its end late. A reading of 0 or less is no reading. A charge never lowers
  the state of charge. If the state at the end is below the state at the start, the session
  gets no states, because both readings are old.

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
`Detection::CarAssignment` explains when a reading is a sign, for example a car that
reports late or is offline.

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

A new build keeps the state of an existing session and its note
(`Detection::Persistence`). A state that the user chose stays, and so does a car that the
detection chose, as long as the period of the car holds the day. A session that the
detection did not assign gets the car of the rules. An offsite session is never touched.
Without a wallbox, the detection does not run, so the sessions of an earlier wallbox stay
as history.

### Proposals

`ChargingSession::OffsiteDetection` finds the charges of a car away from the wallbox. It is
a step of the daily build after the detection, and it writes each charge as a proposal of an
offsite session. A proposal does not count in the numbers of the car page.

A car gets proposals only with its odometer or its position besides the state of charge.
The odometer tells a drive from a charge, and the position tells home. With the state of
charge alone, each rise outside a wallbox session would be a proposal, for example a charge
at a socket at home.

The sign is a rise of the state of charge in one charge (`ChargingSession::SocRuns`):

- A rise needs 5 percentage points, or 3 points while the car reports a connection. The
  connection tells a short charge from noise, for example a new calibration of the battery.
- A drive of more than 1 km ends a rise, so two stops at chargers on one trip give two
  rises.
- A rise at home gives no proposal. There the energy came through the house, or the
  wallbox data has a gap.
- A rise during a wallbox session, or up to 2 hours after it, belongs to that session,
  because a car that is offline during the charge reports the rise late.
- An offsite session of the car with the mark blocks a proposal around its time, and so
  does a dismissed proposal.

A dry run against an installation with all offsite sessions entered by hand confirmed the
thresholds. A threshold of 2 points gave more proposals without a session, also with a
connection, and it found no more sessions. A threshold of 3 points gave no false proposal
and still found small charges.

The build replaces the proposals of its days and keeps each offsite session with the mark.
A proposal stores the state of charge and the position during the rise. The position does
not come from the visits, because a short stop at a fast charger gives no visit. The
estimate is the rise times `battery_kwh`. It is the energy in the battery, so a receipt
shows about 5 to 10 % more for the losses.

An entered or accepted offsite session gets the state of charge of its rise
(`OffsiteDetection::EnteredState`). It also gets the position of the rise, unless it has an
address with a position (see [The position](#the-position)). A wrong value is worse than
none, so a session gets them only when exactly one rise matches its time and no other
session claims it.

### The position

An offsite session has one position: where the car charged (`ChargingSession::Location`).
The position always fits the address:

- A session with an address has the position of its address, from Nominatim (see
  [Address](#address)). Only a street or a building is precise enough.
- A session without an address has the position of its car during its rise, or none.

Without Nominatim (an empty `NOMINATIM_URL`), an address keeps the text of the user and has
no position of its own. Each session then gets the position of its car.

An address that Nominatim does not find is an error, and the form does not save it. If
Nominatim gives no answer, the form does not save a new address either, but the rest of a
session from before still saves. A request to Nominatim takes seconds, so the lookup runs
before the save and outside its transaction (`ChargingSession::AddressLookup`). Each caller
that saves a new address must run the lookup first.

Each address has one form: "DE-12345 Town, Main Street 15" (`Place::PostalAddress`).
Nominatim gives the country, the postcode and the spelling of the street. The town and the
house number come from the user, because Nominatim does not know each house number, and its
town can be a part of the town or a group of towns. A part that the user left out comes from
Nominatim.

The form checks a changed address when the field loses the focus. It then shows the address
in its form and on the map, or the error. The form carries the position, so the save does
not ask Nominatim again. The edit form opens without a request to Nominatim. For an address
without a position, or a position without an address, it asks once it is shown. Without
JavaScript, the save checks the address.

For a session without an address, the form offers the address at the position of the car. A
save with this address keeps the position of the car, because it is more exact. A change of
the car or of the day removes a position that belongs to the rise, and the address that the
form offered at it, unless the user moved the point. The build never changes the position of
an address.

The position of an address is often on the building and not at the charging station. So the
user can move the point on the map of the form, with a drag or a tap, at most 300 m. Only the
position of an address moves, because the build writes the other positions. If exactly one
charging station of the map tiles stands within 150 m, a button moves the point onto it. The
form does not do this by itself, because it cannot tell a position of the car from a
position that the user set.

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
  aggregation `last`). The start of a window is the end of the day before it. The
  `summary_version` of the sensor builds the summaries again where a car has the sensor.
- `k` is the charged energy that raises the state of charge of the car by one percentage
  point (`ChargingSession.kwh_per_percent`). It is the median of the sessions of the car
  with a rise of 20 points or more. It holds the capacity of the battery and the loss of a
  charge in one number, so the correction needs no capacity.
- An offsite session counts for `k`. If its energy is the estimate of its rise, it has no
  loss, so it does not count.
- The cost takes the same share as the energy, so the energy in the battery has the average
  price of the window.
- Without the state of charge at both ends, or with fewer than five sessions for `k`, the
  window keeps its charged energy.

`k` changes with the season. One `k` for each car is sufficient, because its error applies
only to the change of the state of charge, not to all charged energy of the window. The
correction makes the rate of a day change less from the day before. The average state of
charge of a day was not sufficient, because it is wrong on a day with a charge.

A day in the past sits in the center of its window, so a winter day keeps winter data. Four
rules limit a window:

- It ends today. The rate of a recent day can change for 14 more days.
- It starts at the installation date.
- It stays inside the period of use of the car, so the rate of a new car holds no energy of
  the car before it.
- It needs 100 km and charged energy. Without them, the window widens by 14 days on each
  side, up to 42 days. A car that drives little can charge only once a month. A day between
  two such charges then gets the rate of these charges. Without a rate in the window of 42
  days, the day has no rate and no driving cost. The tooltips of the driving cost and the
  rates name the kilometers of such days.

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
driving cost is the money for the kilometers of the period. I18n keeps the terms apart:
`sensors.car_charging_costs` and `sensors.car_driving_costs`.

An example: the car charges 50 kWh today for 10 EUR and drives 10 km. Its window holds
600 km and 30 EUR, so the rate is 5 EUR/100 km. The charging cost of today is 10 EUR, and
the driving cost is 10 km ÷ 100 × 5 EUR/100 km = 0.50 EUR. The rest stays in the battery
for the next days. Over a long period the two numbers come close. A cost is a sum, and a
rate is not. The user interface must never add a rate.

## Charts

| Chart                                                        | Class           | Columns                                                      |
| ------------------------------------------------------------ | --------------- | ------------------------------------------------------------ |
| `car_charging`, `car_charging_costs`                         | `CarSessions`   | PV, grid and offsite, of all selected cars together          |
| `car_consumption_rate`, `car_cost_rate`, `car_driving_costs` | `CarDriving`    | sum of the days of the column, a rate ÷ the distance         |
| `car_distance`                                               | `CarDistance`   | distance of the column, a part for each car, a line on a day |
| `car_battery_soc`                                            | `CarBatterySoc` | min and max of the column, a line on a day, one car          |
| `car_range`                                                  | `CarRange`      | a day only, one car                                          |
| `car_max_range`                                              | `CarMaxRange`   | average of the column, one car                               |

A week and a month have a column for each day, a year for each month, and all for each
year. The live view has no chart. The distance is the default chart, and the charged
energy for a car without an odometer.

The values of two cars do not add up for the state of charge and the ranges, so these
charts need one selected car (`Sensor::Chart::Concerns::OneCar`). The rates stay one
column in "all", for the same reason. In "all" of several cars, the charts of the distance
and the driving cost stack a part of each column for each car. Each part has the color of
the chart with a tint of the color of the car, so the chart keeps the palette of the other
charts in light and dark mode. The tooltip names the car and shows the sum.

A session belongs to a full day, so a day shows other charts: the power curve of the
wallbox (`CarChargingPower`) and its cost (`CarChargingCosts`). With the power splitter,
the curve splits into PV and grid, like the columns. Without the power splitter, a day has
no chart of the charging cost. The rates and the driving cost come from the daily
summaries, so a day has none of their charts.

A day stacks the offsite sessions of the selected cars on the curves of the power and of
the cost of the wallbox. An offsite session has no power curve, so the state of charge and
the plug of its car tell when it charged (`ChargingSession::OffsiteProfile`). Its price,
the cost per kWh, gives the cost of each part.

A day draws the distance since midnight as a line. The line holds each reading until the next
one and steps at a change, like the daily summary (see [Distance](#distance)). The line
therefore ends at the distance on the driving card. Each car has a line of its own, and the
tooltip shows the place of each car at that time from its visits. Between two visits it shows
no place. Only the admin sees these places.

A rate column without a day with a rate has a gap. A column that the installation date,
today or the edge of a range cuts is hatched.

Each chart shows its insights below it (`Car::Insights`): the value of the timeframe, the
change against the previous month and the previous year, and the day with the highest
value.

These rules are decisions:

- A day shows the curves of the power and of the cost of the wallbox without the wallbox
  sessions that count for no selection: a session that is not assigned, a session of
  another car, and a guest session outside the guest and "all". So the curves agree with
  the charged energy and the charging cost of the day. A charge that the detection has not
  found yet stays in the curves. The live view shows the full wallbox.
- The distance has no split by energy source. The source of the energy belongs to the
  charge, not to the drive.

## The car page

The navigation shows `/cars` when at least one car is configured and `Setting.enable_car`
is true, which is the default. Without a car, the car page, the list of the charging
sessions and the settings of the cars stay away, and the detection still writes the
sessions of a wallbox without a car. Without a sponsorship, the page shows an offer
(feature `:car`). The page shows its stats when a car has an odometer or a state of charge.
The odometer adds the driving: the distance, the driving cost and the two rates. A car with
the state of charge alone shows its charging, which takes the full width, and opens the
chart of the charging. A car with neither shows a note that names the missing variables. A
car without a wallbox shows its distance and its
offsite sessions, and the guest badge and the wallbox badge are hidden, not zero.

The car page has no hours view, because its numbers come from full days. An hours
timeframe goes to today.

### The selection of the car

With more than one car, a select in the header of the page chooses one car or "all". The
select applies to the numbers and to the chart. The address has the car in front of the
page (`/cars/2/car_charging/2025`). The list of the charging sessions, the list of the
visits and the map of the places do the same. Each link of the car page keeps the car, and a
link to another page does not get it. Without the car in the address, the page shows "all".

A timeframe offers only the cars in use in it. The select offers "all" also with one car in
the timeframe, because "all" adds the guest sessions to that car. A car that the page
does not offer redirects to "all". The chart menu never names a car, because the select
above it chooses the car.

When the wallbox has a guest session, the select also offers the guest
(`/cars/guest/car_charging/2025`), also in a period without a guest session. The guest has
no car, so the page shows its charging alone, without a frame: the charged energy, the ring
and below it the charging cost and the number of the sessions, which opens their list. The
list links back to the guest. The page has no driving, no badges and only the charts of the
charged energy and of the charging cost. A day shows the curves without the sessions of the
cars. The live view has no guest, so it goes to the live view of the cars. An installation
with one car and without a guest session has no select.

The selection "all" is the sum of the cars and of the guest, and not the sum of the
wallbox. A session that is not assigned counts for no car, because no car is known to have
charged that energy. When the period has such a session, "all" names its energy and links to the list with the filter "not
assigned". A number that is too small without a reason is the one error this page must not
make.

### The live view

The live view shows each car in use today, so it has no select and selects no car. A car in
its address redirects to `/cars/now`. When another timeframe has one car in use, the link
from the live view to it selects that car, also when the timeframe has a guest session.
Otherwise the link goes to "all". An installation without a select keeps "all". Each car
has its name as a badge in its color, a gauge of its range, filled to
the state of charge, its odometer and the time of its latest reading. The time is
necessary, because a car sensor holds its value at any age. For the admin, the gauge also
shows the place of the car. The badge shows also for the only car.

The gauge shows the plug of the car (`car_connected_<n>`) and the charging power in one
badge. Only the car at the wallbox shows the power of the wallbox (`Car::Live`). When no
car is at the wallbox, the live view shows the power below the cars, for example for a
guest. While the car charges, the part of the arc that the charge fills next pulses.

A car without a range sensor gets an estimate of its range (`Car::RangeEstimate`). Its label
says "Estimated range", and a tooltip names the source. The charged energy of a percentage point (`k`, see above) gives a distance at the energy per km
of the last 14 days, or of up to 42 days without a charge in them (`Car::Driving#rate`).
Both are energy at the charger, so the loss of a charge cancels out, and the estimate needs
no capacity. The distance of 100 percentage points
is the range at a full battery, which gives the scale of the arc. The estimate needs `k`, a
rate, and a car in use for 14 days. The energy per km also holds the energy that the car
uses while it stands. So the estimate is lower than the range that a car reports, and the
difference grows when the car drives less per day. The estimate does not correct this,
because the energy that a car uses while it stands is not known.

Each gauge has the same shape. A car without a range and without an estimate shows its state
of charge in the center, at the size of the range, and its arc has no scale. A car without an
odometer shows the counter as inactive boxes. So a car with the state of charge alone shows
its filled arc in the frame of a full car. Without a car in use
today, a gray gauge shows a car icon and "No car is in use at the moment." in its center,
and the admin gets a link to the settings of the cars.

With more than one car, a phone shows a horizontal bar for each car in place of the gauge
(`Car::RangeBar::Component`). The bars stand together in the middle of the page, and a line
parts them. A wider screen keeps the gauges side by side. The bar shows
the same values: the range and the state of charge above it, the scale below it, and
between the ends of the scale the plug and the charging power. Above the bar, the odometer
stands on the right of the name, as high as the name, with the label
"Odometer" below it. The time and the place stand below the name. A gauge for each car did
not fit on a phone, one car below the other. The gauge beside the name and the odometer
did fit, but the row looked crowded.

### A period

A period shows two cards, charging on the left and driving on the right, like the source
and the usage of the power balance. A phone shows one card and a switch between the two,
and a cookie keeps the choice.

- Charging: the charged energy and a ring of its sources: PV, grid and offsite. The center
  of the ring shows the PV share. Without the power splitter, the ring shows the wallbox
  and offsite. Below, the number of wallbox, offsite and guest sessions. The wallbox badge
  counts the cars alone. A guest session belongs to no car, so a selected car shows no guest
  badge.
- Driving: the distance with the average for each day. Below it, four rows: the driving
  cost, its rate per 100 km, the consumption per 100 km and the average maximum range.
  Below, the number of visits and places.

Each value opens its chart, and its tooltip explains it. The tooltip of the ring gives the
share and the cost of each source, and the charging cost. The driving cost gives its
calculation. The two rates give the rule of the 14 days and no calculation, because a
calculation of the rate from the driving cost is circular.

The two rates and the maximum range have a bar below them. The bar places the value between
the lowest and the highest value of the periods of the same kind. A month stands between
the months, and a day between the days. The good end is always on the right, so the bar of
a rate runs from the highest value to the lowest. A mark above the bar points at the value.
It has the color of the third that holds the value. Each end of the bar names its period in
a tooltip and opens that period. If the shown period is an end, the tooltip says so, and
the end has no link.

These rules are decisions:

- The driving cost stands on the card. The charging cost stands only in the tooltip of the
  ring. Over a long period the two are almost equal, so the card shows only one of them.
- On "all", the charging cost holds the cost of the guest sessions. The tooltip of the ring
  shows that part on a line of its own below the charging cost.
- The values show no red, because red marks a low cost as bad. Only the bars show good and
  bad, and each bar knows which end is good.
- Only a day, a week, a month or a year has periods of its kind. The whole time, a relative
  timeframe and a range of dates show no bars.
- A period counts for a bar only when the cars were in use on each of its days. A month in
  which a car started gives a value of a few days. The shown period always counts, so its
  value lies on the bar.
- A bar needs three periods with a value. Fewer periods say nothing.
- A bar reads each day of the whole time. Before it shows the bars, the page therefore
  builds the missing daily summaries of the whole time.
- The mark of a bar has no handle, so the bar does not look like a slider.
- The maximum range comes from the battery, but it tells how far a car can drive, so it
  stands with the driving. Its row stays for "all" with "–", so the layout does not change.
- The badges show also a count of 0, so the layout stays the same.
- No tooltip says that a recent rate can still change. Such a note confused more than it
  helped.

A selected car without an odometer has no driving, so the page shows the charging card
alone. A car with an odometer and without a value in the period shows the driving card with
"–". A period without a car in use shows "No car was in use in the selected period." across
the whole width, without a chart, and the admin gets a link to the settings of the cars.

## Location

`car_latitude_<n>` and `car_longitude_<n>` give the location of a car. The location is
personal data, so only the admin sees it. The definitions declare `admin_only`:

- A guest gets no value of the sensors.
- The list of the visits, the map of the places, the list of the places and the tooltips
  of the places ask a guest to log in. The driving card still shows a guest the number of
  visits and places.
- The MCP server does not offer the sensors.

A position needs the latitude and the longitude. InfluxDB has no type for a point, so a
collector writes two fields, at best in one point. Each coordinate is a state that holds
until its next reading, so the two can also come from separate messages at different times.

The live view shows the place of each car. A click on the place opens the latest location
on a map that fills the window. A map in the live view took too much space beside the
gauge, and a place says enough at a glance.

The map of the places is a page below the car page (`/cars/2/places/2025`), like the list
of the visits. The badge of the places on the driving card opens it. The page has a
timeframe and a select of the car, and the map fills the page. A chart beside the numbers
of the car page was too small for a map.

The map shows a circle for each place of the selected cars. The area of a circle shows the
share of the time that the cars spent at that place. Each point has one color, also for a
single car, because the color of a car marks the car and not its places. One circle for
each car and place was the other choice, but then the visits in the tooltip of a car did
not match the list of the visits of all cars. The tooltip of a place links the visits of
that place.

The map of the places is a page of its own and not a view of the list of the visits, because
a visit and a place are different things. The map of the offsite sessions is a view of their
list, because it shows the same sessions.

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
position within 100 m of the stop before into this stop.

Each stop has a limit:

- A stop at no place and shorter than its limit gets no place, for example a traffic light.
- A visit shorter than its limit is left out, for example a drive past the home.
- Two visits at one place make one visit when less time than the limit lies between them.

A drive past a place has one reading there and lasts one interval of the readings. A visit
has two readings and lasts two intervals. The limit is therefore 1.5 intervals, at least 30
minutes and at most 3 hours. The interval comes from the readings at the stop, so it
follows the user when the car reports more often.

Some cars report only a change, and some of them report only at the arrival, not on the
road. Such a car sends one reading at a stop, and the time before this reading is the time
at the place before. If the car sent nothing during the whole stop before, this time gives
no interval. The limit of the new stop is then 30 minutes, also with one reading. A car that
reports on the road keeps its limit, because a position of the drive comes before each
arrival.

The step cuts the visits at midnight, like a daily summary. The list of the visits
(`/cars/visits`) joins these rows again and shows a visit that is still going on without
an end.

### Places

The table `places` holds the places where the cars stood. A stop that reaches its limit gets
a place when no place is within 100 m. Only the daily build makes a place, because a car on
the road must not leave places behind. The user gives a place a name, for example "Home".
Without it, a place shows its town. The list of the places is a page of the settings.

A place has labels (`Place::LABELS`). The labels are a string array, so a new label needs no
migration. The label "Home" marks the place of the wallbox, and only one place has it. The
assignment of the charging sessions uses it (see [Which car charged](#which-car-charged)).
The proposals of the offsite sessions use it too.

Both read home only at a position of a car. A position lasts until the next reading, so a
parked car also has a position on a day without a reading. A new home therefore removes the
summaries of each car with a location, from its first position in InfluxDB to the end of its
period of use (`Place::HomeChange`). Without such a car, the summaries stay. If InfluxDB
cannot give the first position, all summaries go (see
[When the detection runs](#when-the-detection-runs)).

A place stays when its visits go, also after "Delete the summaries". So a place from wrong
positions stays after the user corrects the positions in InfluxDB. The list marks a place
without a visit as never visited. Its page offers its deletion alone (`Place#deletable?`),
because a name or home makes no sense for it. A place with visits stays, because its days would lose their visits. Home stays too, because a
new home builds the days again.

### Address

The address comes from Nominatim, the geocoder of OpenStreetMap (`Place::Nominatim`). The
position of the address of an offsite session comes from it too. Its
[usage policy](https://operations.osmfoundation.org/policies/nominatim/) allows one request
per second and no periodic requests. So SOLECTRUS asks it only when the user asks for a
place:

- A click on the place of a car in the live view, or its badge without a name.
- The edit form of a place.
- The tooltip of a place on the map of the places.
- The edit form of an offsite session with only an address or only a position, once it is
  shown.
- A changed address in the form of an offsite session, when the field loses the focus.
- The save of an offsite session with a new address that the form did not check.

A place asks once and keeps the answer. A location without a place gets no new place. The
build and the list of the sessions ask nothing, because the backfill asks for each charge
of the history. The usage policy forbids an autocomplete, so the form asks nothing while the
user types. The policy also requires a cache, which keeps the answer to an address for a
week.

`NOMINATIM_URL` selects another server of Nominatim, for example one of your own. The usage
policy requires this switch without a software update. If `NOMINATIM_URL` is set but empty,
SOLECTRUS sends no location to Nominatim. A place then shows no town, and the badge shows
"Location".

The request sends a User-Agent with the version of the app and the word "self-hosted". All
installations send the same User-Agent, so the word tells the operators of Nominatim that
each IP address is a separate installation.

## MCP

The numbered sensors `car_battery_soc_<n>`, `car_odometer_<n>`, `car_range_<n>`,
`car_max_range_<n>` and `car_connected_<n>` reach MCP as all sensors do. The location of a
car does not reach MCP (see [Location](#location)).

`car_odometer_<n>` has two meanings. A live value and a curve give the odometer reading. A
total, a period and a ranking give the distance driven. Its description says both.

The charts of the car page have no number. MCP has no selection of a car, so most of them
get no tool, and `list_sensors` does not list them. `car_distance` is the exception: it
adds up the cars, so `get_ranking` ranks it. A client that asks for a role like
`car_battery_soc` gets the numbered sensors of the cars with their names, for example
`car_battery_soc_1 (Model Y)`. This matters because `car_battery_soc` was a sensor with
values before cars had numbers. The charging and the rates have no MCP tool yet.
