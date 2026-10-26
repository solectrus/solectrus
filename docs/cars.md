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

| Class                               | Job                                                                     |
| ----------------------------------- | ----------------------------------------------------------------------- |
| `Car`                               | a car: number, name, color, period of use, `Car.configured`             |
| `Car::PeriodChange`                 | what follows when the period of use of a car changes                    |
| `Sensor::Cars`                      | the numbers and the sensor names of the cars, without a database        |
| `ChargingSession`                   | a charge of a car, at the wallbox or offsite                            |
| `ChargingSession::Sums`             | the sums of a set of sessions: count, energy, cost, PV share            |
| `ChargingSession::Detection`        | finds the wallbox sessions in the power curve of a day                  |
| `ChargingSession::OffsiteDetection` | proposes offsite sessions from the state of charge of a day             |
| `ChargingSession::AddressLookup`    | the position of the address of an offsite session, from Nominatim       |
| `Car::Ledger`                       | the car days of a date range: distance and session sums                 |
| `Car::Driving`                      | the rates of each day from its window                                   |
| `Car::Report`                       | the numbers of a timeframe, for the page and for its charts             |
| `Car::Spans`                        | the lowest and the highest rate of the periods of one kind              |
| `Car::DayTimeline`                  | the drives, the charging sessions and the state of charge of a day      |
| `Car::Live`                         | the live values of the wallbox and of each car                          |
| `CarSelection`                      | the selected car (`/cars/2/…`) on the car page and in the lists         |
| `Car::Section`                      | the two columns of the overview, driving and charging, and their charts |
| `Place`, `Place::VisitDetection`    | the places where the cars stood, and the visits there                   |

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

The color of a car marks it where cars stand side by side, and in the charts of all cars
(see [Charts](#charts)). The sensors of a car keep their own colors, because each sensor has
its own meaning.

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
| `car_max_range`        | none, chart only                    | none                | max. range of one car        |

The registry makes the seven sensors of a car for each number up to `MAX`, and
`Sensor::Config` removes a number without a configuration. These sensors hold the data.
The car page shows only the chart-only sensors, which have no number. The select of the car
chooses the car, and the chart menu chooses the chart. The chart menu offers no chart that
the selected cars cannot draw, like the distance of a car without an odometer, and an
address of such a chart goes to the default chart.

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
energy of each day stays on its day. An offsite session over midnight stays one session, but
the timeline of each day shows its part (see [The day](#the-day)).

### The list

The list of the sessions is a page below the overview (see [The lists](#the-lists)), for
example `/cars/1/charging_sessions/offsite/2025`. A switch above the list chooses the kind:
the wallbox sessions or the offsite sessions. Without a wallbox, the list shows the wallbox
sessions only while sessions of an earlier wallbox exist, and without them it has no switch.

The list shows the sessions of the selected car, like the chart: one car, "all" or the
guest. "All" holds the cars and the guest. The head of the list shows the sums of the kind:
the number of the sessions, the energy and the cost. The sums are the sessions that count,
so they agree with the chart. An empty list has no sums, and its text names the selected car
or the guest. A guest charges at the wallbox alone, so the list of the guest has no switch
and no button for a new session.

The admin also sees the sessions to review in the list: the proposals of the offsite
sessions, and the wallbox sessions that are not assigned. The sums leave them out. A filter
shows them alone, and the proposals there go at once with "Dismiss all". The car page marks
a list with sessions to review. A wallbox session that is not assigned can be the charge of
any car, so the list and the car page of a car or of the guest name it too, and the link
opens the list of "all". A guest sees nothing to review, no address of an offsite session
and no form.

The list groups its rows by month, week or day, like the other lists (see `Timeframe::RowGroups`).

The offsite sessions have a map over their list, which only the admin sees. The map has no
page of its own, so its address alone leads to the list. The wallbox sessions have no map,
because they all share one place. The sessions in one cell of about 100 m share a circle,
and the area of the circle shows the share of the energy. A note on the map counts the
sessions without a position.

The user changes the car, the guest mark and the note of a wallbox session. The detection
writes its time, energy and cost, so the form shows them read-only. A new session is always
`offsite`, because a guest charge that no wallbox measured has no energy and no cost. The
list deletes only an offsite session. An offsite session records a charge that took place,
so the form refuses a start or an end after now, and an end that is not after the start
(`ChargingSession::EnteredTime`).

The list shows a proposal with its estimate, but its sums leave it out. A save in the form
accepts a proposal, so the form needs the cost. The user can also dismiss a proposal. A
row above the list of the proposals alone dismisses all of them at once, for
a time without receipts ([#6021](https://github.com/solectrus/solectrus/issues/6021)). It
dismisses only the proposals that the list showed, so a proposal of a later build stays.

The form shows the loss of a charge: 1 − rise ÷ 100 × `battery_kwh` ÷ `kwh`. A loss in each
row added no value to the list. The loss needs a rise of 20 points or more, because the
state of charge has whole percents. The form names it a rough estimate, because
`battery_kwh` is seldom exactly the capacity that the state of charge refers to. A loss
far from the usual values is a sign of a wrong state of charge
([#6056](https://github.com/solectrus/solectrus/issues/6056)).

The state of charge does not always fit the energy (`ChargingSession::StateOfCharge`):

- A negative loss means that the state of charge rose more than the energy explains. The
  form shows this sentence and no number. The scale of the state of charge changes with
  the temperature of the battery, so a point can hold a quarter less energy in winter.
- A rise contradicts the energy when the battery surely got less than half of the energy
  or more than one and a half times it, for example 75 → 75 % with 20 kWh. The car then
  reported no current values during the charge. The form explains this. Each end can be
  off by one point, because the state of charge has whole percents. A full car can take
  energy without a rise, so a rise to 99 % is never too small.

The list shows a charge over midnight in one row (`ChargingSession.joined`), and a count
counts it once. The data keeps a session for each day, so the daily sums and the charts
stay exact. The list has no hours view, like the car page.

The detection writes the end of the latest bucket with power. So a charge that goes on gets
an end and a state of charge at the end that change with each build. The list shows such a
session as ongoing, without its end. A session is ongoing when it reaches the latest build
of today within the gap of the detection, and the wallbox reports power now. The table does
not store this state, like for an ongoing visit (see [Visits](#visits)).

### The detection

`ChargingSession::Detection` finds the wallbox sessions in the wallbox curve of a day:

- A session is a continuous period with `wallbox_power > 0`, found on the 5-minute means.
  A gap of 15 minutes or less does not end it, because load management and PV surplus
  control make such gaps.
- `wallbox_car_connected` bridges a longer gap, but it never moves an end. Otherwise a
  charge before the sensor reports the connection loses its energy. The timeline of the day
  shows such a gap as a pause (see [The day](#the-day)).
- A 5-minute bucket without a reading is no data, not 0 W. A collector can fail for an
  hour while the car charges. Such a gap does not end a session. A session also reaches
  across a gap at each end, to the next bucket with data. The daily sum integrates across
  the gap from the last value to the next one, so the sessions keep the energy of the day.
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
- A drive does not raise the state of charge. If the step between two readings holds a
  drive and a rise, the car charged within the step. Such a step of 30 minutes or less at
  the start or at the end of a charge adds its rise to the state of charge, but not its
  time. Otherwise a car that reports every 20 minutes loses a large part of its rise
  ([#6056](https://github.com/solectrus/solectrus/issues/6056)). An odometer that reports
  the end of a drive late gives the same step. A longer step can hold a charge of its own,
  and a drive between two charges belongs to neither. Against the receipts of one
  installation, the rule halved the spread of the energy per percentage point.
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

The form checks a changed address before the save and carries its position, so the save
does not ask Nominatim again.

For a session without an address, the form offers the address at the position of the car. A
save with this address keeps the position of the car, because it is more exact. A change of
the car or of the day removes a position that belongs to the rise, and the address that the
form offered at it, unless the user moved the point. The build never changes the position of
an address.

The position of an address is often on the building and not at the charging station. So the
user can move the point on the map of the form, at most 300 m. Only the position of an
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
driving cost is the money for the kilometers of the period. I18n keeps the terms apart:
`sensors.car_charging_costs` and `sensors.car_driving_costs`.

An example: the car charges 50 kWh today for 10 EUR and drives 10 km. Its window holds
600 km and 30 EUR, so the rate is 5 EUR/100 km. The charging cost of today is 10 EUR, and
the driving cost is 10 km ÷ 100 × 5 EUR/100 km = 0.50 EUR. The rest stays in the battery
for the next days. Over a long period the two numbers come close. A cost is a sum, and a
rate is not. The user interface must never add a rate.

## Charts

| Chart                                                        | Class           | Columns                                              |
| ------------------------------------------------------------ | --------------- | ---------------------------------------------------- |
| `car_charging`, `car_charging_costs`                         | `CarSessions`   | PV, grid and offsite, of all selected cars together  |
| `car_consumption_rate`, `car_cost_rate`, `car_driving_costs` | `CarDriving`    | sum of the days of the column, a rate ÷ the distance |
| `car_distance`                                               | `CarDistance`   | distance of the column, a part for each car          |
| `car_battery_soc`                                            | `CarBatterySoc` | min and max of the column, one car                   |
| `car_max_range`                                              | `CarMaxRange`   | average of the column, one car                       |

A week and a month have a column for each day, a year for each month, and all for each
year. The live view and a day have no chart. A day has the timeline of the day in the place
of the charts (see [The day](#the-day)). Each chart belongs to a column of the overview, the
charging or the driving (`Car::Section`). A chart that cannot draw the timeframe or the
selection goes to the overview without a chart in the address.

The values of two cars do not add up for the state of charge and the ranges, so these
charts need one selected car (`Sensor::Chart::Concerns::OneCar`). The rates stay one
column in "all", for the same reason. In "all" of several cars, the charts of the distance
and the driving cost stack a part of each column for each car.

A rate column without a day with a rate has a gap. A column that the installation date,
today or the edge of a range cuts is hatched.

Each chart shows its insights below it (`Car::Insights`): the value of the timeframe, the
change against the previous month and the previous year, and the day with the highest
value. A rate and the maximum range also name the best and the worst period of the same
kind, with a link to each (see `Car::Spans`). The overview shows only where the value lies
between them, so the way to these periods is in the insights.

The distance has no split by energy source. The source of the energy belongs to the charge,
not to the drive.

## The car page

The navigation shows `/cars` when at least one car is configured and `Setting.enable_car`
is true, which is the default. Without a car, the car page and the settings of the cars stay
away, and the detection still writes the sessions of a wallbox without a car. Without a
sponsorship, the page shows an offer (feature `:car`). The page shows its numbers when a
car has an odometer or a state of charge. A car with neither shows a note that names the
missing variables.

The car page has two levels. The live view and the overview of a period are the top. Below
the overview are the list of the charging sessions and the list of the places. A third level
does not exist. The maps fill the window over their list, like the location of a car over
the live view, and a filter narrows a list in place, so neither adds a level.

The car page has no hours view, because its numbers come from full days. An hours
timeframe goes to today.

### The selection of the car

With more than one car, a select in the header chooses one car or "all". On a phone, chips
below the period do this (`Ui::Chips`). The live view has no select, because it shows each
car in use with its name. The address has
the car in front of the page (`/cars/2/2025`, `/cars/2/car_charging/2025`). The lists do the
same. Each link of the car page keeps the car, and a link to another page does not get it.
Without the car in the address, the page shows "all".

A timeframe offers only the cars in use in it. The select offers "all" also with one car in
the timeframe, because "all" adds the guest sessions to that car. A car that the page does
not offer redirects to "all". The chart menu never names a car, because the select above it
chooses the car.

When the wallbox has a guest session, the select also offers the guest
(`/cars/guest/2025`), also in a period without a guest session. The guest has no car, so the
page shows its charging alone and has no driving. A day shows the curves without the
sessions of the cars. The live view has no guest, so it goes to the live view of the cars.
An installation with one car and without a guest session has no select.

The selection "all" is the sum of the cars and of the guest, and not the sum of the wallbox.
A session that is not assigned counts for no car, because no car is known to have charged
that energy. When the period has such a session, the overview names its number and its
energy for "all", and its link opens the list of the wallbox sessions. A number that is too
small without a reason is the one error this page must not make.

### The live view

The live view shows each car in use today, so it has no select and selects no car. A car in
its address redirects to `/cars/now`. When another timeframe has one car in use, the link
from the live view to it selects that car, also when the timeframe has a guest session.
Otherwise the link goes to "all". An installation without a select keeps "all".

Each car has a section of its own (`Car::LiveCard::Component`):

- The name of the car and the time of its latest reading. The time is necessary, because a
  car sensor holds its value at any age.
- The range, and the state of charge on the scale from 0 to the maximum range. A car
  without a range and without an estimate shows its state of charge alone.
- For the admin, the place (`Car::LocationRow::Component`), which opens the map.
- The plug of the car (`car_connected_<n>`), with the charging power while the car charges.
- The odometer.

Only the car at the wallbox shows the power of the wallbox (`Car::Live`). When the wallbox
charges and no car shows its power, the live view adds a card of the wallbox with the
charging power. With the plugs of the cars, a guest charges, so the card names the guest.
Without them, the card names the wallbox. Without a car in use today, the live view says
so, and the admin gets a link to the settings of the cars.

A car without a range sensor gets an estimate of its range (`Car::RangeEstimate`), and the
live view names it an estimate. The charged energy of a percentage
point (`k`, see above) gives a distance at the energy per km of the last 14 days, or of up
to 42 days without a charge in them (`Car::Driving#rate`). Both are energy at the charger,
so the loss of a charge cancels out, and the estimate needs no capacity. The distance of 100
percentage points is the range at a full battery, which gives the scale of the bar. The
estimate needs `k`, a rate, and a car in use for 14 days. The energy per km also holds the
energy that the car uses while it stands. So the estimate is lower than the range that a
car reports, and the difference grows when the car drives less per day. The estimate does
not correct this, because the energy that a car uses while it stands is not known.

### The overview

The overview of a period has two columns: the driving and the charging (`Car::Section`), in
the order of the rows of the timeline of a day.
Each column has three figures. A week, a month, a year and the whole time show the chart of
one figure below them. A click on a figure loads its chart into its column, and the address
keeps the chart.

A day has no charts. It shows the timeline of the day below the figures (see
[The day](#the-day)). The overview has no insights. Each column links its list: the charging
links the charging sessions, and the driving links the places.

The sensor of the chart in the address chooses the chart of its column, for example
`/cars/2/car_cost_rate/2025`. The other column shows its first chart. Without a sensor
(`/cars/2/2025`), each column shows its first chart. The address of a day has no sensor. An
address of a day with a sensor goes to the same day without it.

- Charging: the charged energy, the charging cost and the state of charge.
- Driving: the distance, the driving cost, the two rates, the maximum range and the range.

The figures of each column (see `Car::OverviewBox::Component`):

- Charging: the charged energy, the share of PV and the charging cost. The tooltip of the
  energy has the energy of each source. Below the share, a bar shows the sources side by
  side: PV, grid and offsite. Without the power splitter, the share is the one of the
  wallbox, and the bar shows the wallbox and offsite. The tooltip of the cost has the cost
  of each source and, on "all", the cost of the guest.
- Driving: the distance with the average distance of a day, and the cost and the
  consumption per 100 km. On "all", a bar below the distance shows the share of each car,
  and its tooltip has the distance of each car. Each rate has a bar of its place among the
  periods. The tooltip of a rate has the driving cost or the energy used that gives it. An
  info icon beside the title of the column names the window of the rates.

The chart menu of a desktop offers the charts of its column alone. A phone shows one chart
below the figures of both columns: the chart of the column of the last tap. Its chart menu
offers the charts of both columns.

The bar of a rate places the value between the lowest and the highest value of the periods
of the same kind (`Car::Spans`). A month stands between the months, and a day between the
days. The good end is always on the right, so the bar of a rate runs from the highest value
to the lowest. The best and the worst period stand in the insights of the chart.

These rules are decisions:

- The figures show no comparison with the previous month or year. Only the insights show
  them.
- The values show no red, because red marks a low cost as bad. The bars of the rates show no
  red either. The good end on the right and the numbers at the ends tell good and bad.
- The overview has no ring. The ring of the distance of one car was always full and told
  nothing. Three figures in a row read the same on a phone and on a desktop.
- Only a day, a week, a month or a year has periods of its kind. The whole time, a relative
  timeframe and a range of dates show no bars.
- A period counts for a bar only when the cars were in use on each of its days. A month in
  which a car started gives a value of a few days. The shown period always counts, so its
  value lies on the bar.
- A bar needs three periods with a value. Fewer periods say nothing.
- A bar reads each day of the whole time. Before it shows the bars, the page therefore
  builds the missing daily summaries of the whole time.

A selected car without an odometer has no driving, so the page shows the charging alone. The
guest has no driving either. A column without a value in the period keeps its figures with 0
or "–". A period without a car in use says so, and the admin gets a link to the settings of
the cars.

### The day

The overview of a day shows the timeline of the day below the figures, in the place of the
charts (`Car::DayTimeline::Component`). The timeline loads with the figures and refreshes
with them. Its axis is the local day from 0:00 to 24:00, so a day of a change of the clock
has 23 or 25 hours on the same width.

Only the admin sees today and yesterday (`Car::AdminOnlyDays`). Such a day shows when the cars
drove and charged, so it tells when someone is away from home. A guest gets a note with the
login, and the figures of such a day do not load for a guest. An older day stays public, so
a visitor of the demo sees the page some days back. The live view stays public too, because
it shows no time of a drive.

A longer period, like a week, ends with the day before yesterday for a guest. Its figures,
its charts and the spans of its rates leave out today and yesterday, because their amounts
tell the same as their times. A note above the figures says so, with the login, so someone
who only forgot to log in sees why the latest days are missing. The navigation keeps the
periods as they are, so the tab of the day still leads to today. The insights of a chart of
the car page and the Top 10 of a sensor of a car end with the same day. The state of charge
of a car on the power balance stays public, like the live view.

The list of the charging sessions leaves out the sessions of such a day for a guest, also in
its sums. Its time and its energy would tell the same, and a large offsite charge tells that
the car is far away. The list is split by kind, so a row without its details would still
tell an offsite charge. A note names the hidden days whenever the list holds them, also
without a session there, so the note tells nothing itself.

The timeline of a car has three rows:

- The drives, each from its start to its end.
- The charging sessions, each from its start to its end, and the times in which the car was
  plugged in but did not charge. The sources of the energy of a session stack from the
  bottom up, each as high as its share, because parts side by side read as one after the
  other in time.
- The state of charge, as a line through its readings (see
  [The line of the state of charge](#the-line-of-the-state-of-charge)).

A car without an odometer has no row of the drives, and a car without a state of charge has
no line. On "all", each car has a timeline of its own, without the color of the car. The
guest has a timeline with its charging alone: for the guest, and on "all" when the day has a
guest session. The running day ends at now. In the live view, the state of charge and the
odometer of a car link to today with the car selected.

The tooltip of a bar names what the car did, its time and its place, and its numbers. Only
the admin sees the places: the start and the goal of a drive from the visits of the day (see
[Visits](#visits)), and the address of an offsite session.

The sessions with their start and their end come from the table. A running session charges
until now. A session that charged over midnight shows on both days, each day with its part.
Its bar is open at midnight, and on the next day a note says that it counts for the day on
which it started, like in the figures above the timeline.

An offsite session without an end has no time of its own, so the readings of its car give
the signs (`Car::DayTimeline::OffsiteEstimate`). A rise of the state of charge comes first.
Without a rise, the time in which the plug reads connected counts. Without both, the rest of
the day counts, up to the start of the next session of the car. A drive and another session
of the car give no sign, because the car does not charge there. Of all signs, the run with the most weight wins, so a small rise at
another charger does not move the charge. The timeline marks this time as an estimate.

The estimate reads the same readings as the line of the state of charge and the time
plugged in, so the three fit together.

A session at the wallbox can pause while the car stays plugged in, for example until the
cheap tariff of the night. The detection joins the parts with power over such a pause only
when the plug of the wallbox reads connected through it (see [The detection](#the-detection)).
So the session stays one bar with its pause in it, and its energy and its cost stand once.

The plug of a car (`car_connected`) tells the times in which it was plugged in: each time in
which it reads plugged in, without the time of a session and of a drive. A reading holds
until the next one. A car reports late that it was unplugged, so a drive ends the time
plugged in. A rest of less than 5 minutes is the offset of a reading to its session, so it
does not count. The plug of the wallbox does not tell which car is plugged in, so it gives
no time plugged in.

Driving never overlaps charging or a time plugged in. A drive gives way to a session that
the car recorded, because the table holds its time. A session with an estimated time gives
way to a drive, because the odometer tells the drive.

The curves are those of the daily build (`ChargingSession::Curves`): the curves of the
wallbox, and the odometer, the plug and the state of charge of each car, each from its last
reading before the day. A state of charge of 0 or above 100 is no reading
(`ChargingSession::Curves.soc_reading?`).

#### The drives

No table holds the drives, so `Car::DayTimeline::Drives` finds them in the readings of the
odometer and of the state of charge. A car reports at a pace of its own, and the collectors
differ too. Some write the odometer while the car drives. Others write the odometer of the
start until the car stops, so its increase comes after the drive.

These rules find the drives:

- An increase of the odometer is a drive from the reading before it to the reading with it.
- If the reading before the increase is more than 1 hour earlier, the start is not known.
  Up to 3 hours, like a missed reading of a car that reports each hour, that reading is the
  earliest start. The bar starts there with a jagged edge, and its tooltip says that the
  start is an estimate. A drive that joins it keeps the estimate.
- The state of charge falls while the car drives, also when the odometer stands still. So
  the drive ends with the last fall before the increase. It starts where the state of
  charge began to fall without a pause, but not before the car arrived at the place that
  the drive leaves. A fall of one point over more than 30 minutes is noise and no drive,
  like a cold battery while the car stands.
- Drives that overlap are one drive.
- A pause of up to 30 minutes joins two drives, because the state of charge can stand still
  for a reading while the car drives.
- A charging session or a visit of a place in the pause keeps the two drives apart, because
  the car stood there.
- A drive ends where a charging session or a visit starts in its last 15 minutes. A car
  reports up to 15 minutes late, like for the choice of the car of a wallbox session (see
  [Which car charged](#which-car-charged)). So the reading with the increase can come some
  minutes after the car arrived and plugged in. The drive ends there before it joins
  another one, so an arrival keeps two drives apart.

A car reports its place late, so a visit can last until the car arrives at the next place,
and only the start of a visit is sure. A drive therefore starts at the last place where the
car arrived before it.

A wrong reading of the odometer adds no drive, like in the distance of the day (see
[Distance](#distance)).

The distance of a drive must fit its time. Below 5 km/h on average for longer than 20
minutes, the time is only the window between two readings, in which a short drive took
place. Above 150 km/h, the start is too late. The bar of such a drive has a jagged edge,
both edges for a window, and its tooltip says why. A drive without a start says so too.

#### The line of the state of charge

`Car::DayTimeline::SocLine` draws the line from the readings of the state of charge. The line
starts with the value at the start of the day, which is the last reading before it.

These rules draw the line:

- If two readings are 1 hour apart or less, the line holds the first value and steps at the
  second, like the chart of the state of charge.
- If two readings are further apart, a step at the second reading comes too late. A car
  that charged at noon and reported in the evening would rise in the evening. So a rise
  follows the charging sessions between the two readings, and a fall follows the drives.
- If no charging session and no drive explain the change, nothing tells when the value
  changed. The line is then a slope from one reading to the next, marked as unknown.
- A change of one percentage point steps at its reading, because it is the noise of the
  reading.

The state of charge before and after a drive comes from the line.

### The lists

The list of the charging sessions and the list of the places are pages below the overview.
Each has a timeframe and a select of the car, and its way back leads to the overview in the
same timeframe and with the same car. On a phone, the overview opens both lists in a sheet,
with their forms as pages of the sheet (see the section "Sheets with pages" in
[docs/ui.md](ui.md)).

- The charging sessions (`/cars/2/charging_sessions/wallbox/2025`, see [The list](#the-list)).
  The admin adds an offsite session there. The link from the wallbox on the power balance
  opens the list too.
- The places (`/cars/2/places/2025`) and the visits (`/cars/2/visits/2025`), see
  [Location](#location). Only a car with a location has places, so without one the overview
  has no link to them.

## Location

`car_latitude_<n>` and `car_longitude_<n>` give the location of a car. The location is
personal data, so only the admin sees it. The definitions declare `admin_only`:

- A guest gets no value of the sensors.
- The lists of the places and of the visits, the map of the places and the tooltips of the
  places ask a guest to log in. The overview still shows a guest the link to the places.
- The MCP server does not offer the sensors.

A position needs the latitude and the longitude. InfluxDB has no type for a point, so a
collector writes two fields, at best in one point. Each coordinate is a state that holds
until its next reading, so the two can also come from separate messages at different times.

The live view shows the place of each car in a row. A car at a place shows the name of the
place. A car at no place is on the road. Its row names the town near its latest
position and how old the position is. A car that drove away from its latest position is on
the road without a town. The row opens the latest location on a map. A map in the live view
took too much space, and a place says enough at a glance.

The list of the places shows the places of the selected cars: each place with its cars, the
number of its visits and its latest visit, the most visited place first. A switch shows the
visits instead, the latest first. A place or a visit opens the place with its map and its
name. The number of the visits of a place opens the list of the visits with the place as a
filter (`/cars/places/2/visits/2025`).

The map of the places lies over the list, with the timeframe and the car of the list. A
chart beside the numbers of the car page was too small for a map, and a page of its own
added a third level.

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
joins these rows again and shows a visit that is still going on without
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

- A click on the place of a car in the live view, or its row without a name.
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
SOLECTRUS sends no location to Nominatim. A place then shows no town, and a car on the
road shows no town either.

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
