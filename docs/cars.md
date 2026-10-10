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

| Class                               | Job                                                              |
| ----------------------------------- | ---------------------------------------------------------------- |
| `Car`                               | a car: number, name, color, period of use, `Car.configured`      |
| `Car::PeriodChange`                 | what follows when the period of use of a car changes             |
| `Sensor::Cars`                      | the numbers and the sensor names of the cars, without a database |
| `ChargingSession`                   | a charge of a car, at the wallbox or offsite                     |
| `ChargingSession::Sums`             | the sums of a set of sessions: count, energy, cost, PV share     |
| `ChargingSession::Detection`        | finds the wallbox sessions in the power curve of a day           |
| `ChargingSession::OffsiteDetection` | proposes offsite sessions from the state of charge of a day      |
| `Car::Ledger`                       | the car days of a date range: distance and session sums          |
| `Car::Driving`                      | the rates of each day from its window                            |
| `Car::Report`                       | the numbers of a timeframe, for the page and for its charts      |
| `Car::Live`                         | the live values of the wallbox and of each car                   |
| `CarSelection`                      | the selected car (`/cars/2/…`) on the car page and in the lists  |
| `Place`, `Place::VisitDetection`    | the places where the cars stood, and the visits there            |

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
| `color`        | a hex code like `#3b82f6`          | the default color (indigo)                     |
| `battery_kwh`  | the usable capacity of the battery | no capacity                                    |

`Car.configured` gives the cars of the configured numbers. It creates a missing car on the
first request that needs one, so a user with one car has nothing to do. It is not part of
`Sensor::Config`, because a database write at configuration time couples the two layers.

The number of a car never changes, because the daily values store its history under the
sensor name with the number. SOLECTRUS never removes a car, so a sold car keeps its number
and its history. The car management page (`/settings/cars`) edits the columns. It adds no
car, because a configured number gets its car by itself.

### Name and color

The name of a car sensor is the car name plus the role: "Model Y (SOC)". The name of a car
is personal data, so only the admin sees it. A guest sees "Car 2" in each place. The short
name stands where a long name takes too much space, for example in the button of the car
select.

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
| `car_location`         | none, chart only                    | none                | places of the cars on a map  |

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
aggregation `sum`. A car writes its odometer only while it is online, so a day can have one
reading or none. The build therefore interpolates the odometer at each midnight between the
readings around it (`Influx::DailyDiffs`). The daily values then add up exactly: the sum of
a range is the odometer at its end minus the odometer at its start. A day before the first
reading has no value, so an odometer that comes after the installation gives no distance of
0 for the time before it.

A day that the build makes during a gap in the readings ends at the last reading and gets
none of the distance of the gap. When the next reading comes, a later build finds the gap
(`Sensor::Summarizer::MeterGaps`) and builds the days of the gap again. A gap without a
change of the odometer builds no day again.

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

| State        | `car_id` | `guest` | Counts for                 |
| ------------ | -------- | ------- | -------------------------- |
| car          | set      | false   | the car                    |
| guest        | NULL     | true    | no car, its cost is a loss |
| not assigned | NULL     | false   | no car, "all" names it     |

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
the settings switch the car page off, the list goes to the start page. Without a
sponsorship, it goes to the offer of the car page.

The list has a tab for each kind and a filter of the car in the header: one car, "all", for
the wallbox also "not assigned" and the guests, and for offsite the proposals.
`CarSelection` gives the filter, like the select of the car page, so it offers only the
cars in use in the timeframe. Without a wallbox, the tab of the wallbox sessions shows only
while sessions of an earlier wallbox exist.

The user changes the car, the guest mark and the note of a wallbox session. The detection
writes its time, energy and cost, so the form shows them read-only. A new session is always
`offsite`, because a guest charge that no wallbox measured has no energy and no cost. The
list deletes only an offsite session.

The list shows a proposal with its estimate, but its sums leave it out. A save in the form
accepts a proposal, so the form needs the cost. The user can also dismiss a proposal.

The form shows the loss of a charge: 1 − rise ÷ 100 × `battery_kwh` ÷ `kwh`. A loss in each
row added no value to the list. The loss needs a rise of 20 points or more, because the
state of charge has whole percents.

The list shows a charge over midnight in one row (`ChargingSession.joined`), and a count
counts it once. The data keeps a session for each day, so the daily sums and the charts
stay exact. The list keeps the hours view, because the sessions of the last 24 hours are a
useful list.

### The detection

`ChargingSession::Detection` finds the wallbox sessions in the wallbox curve of a day:

- A session is a continuous period with `wallbox_power > 0`, found on the 5-minute means.
  A gap of 15 minutes or less does not end it, because load management and PV surplus
  control make such gaps.
- `wallbox_car_connected` bridges a longer gap, but it never moves an end. Otherwise a
  charge before the sensor reports the connection loses its energy.
- A session needs 0.1 kWh at least, because many wallboxes report a standby power.
- The energy comes from the integral of the power, like the daily sum. The grid share comes
  from `wallbox_power_grid` in the same way.
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
- A new home resets the summaries at once, because the detection and the proposals read
  it.
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
thresholds. A threshold of 2 points gave 11 proposals without a session instead of 3, and
it found no more sessions. With 2 points and a connection, it gave 6 false proposals. With
3 points, it gave none and found a charge of 1.9 kWh.

The build replaces the proposals of its days and keeps each offsite session with the mark.
A proposal stores the state of charge and the position during the rise. The position does
not come from the visits, because a short stop at a fast charger gives no visit. The
estimate is the rise times `battery_kwh`. It is the energy in the battery, so a receipt
shows about 5 to 10 % more for the losses.

An entered or accepted offsite session gets the state of charge and the position of its
rise (`OffsiteDetection::EnteredState`). A wrong value is worse than none, so a session
gets them only when exactly one rise matches its time and no other session claims it.

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
  A guest session and a session that is not assigned count for no car.
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
EUR/100 km of a day    =  cost of its window    ÷  distance of its window  × 100
kWh/100 km of a day    =  energy of its window  ÷  distance of its window  × 100
driving cost of a day  =  distance of the day   ÷  100  ×  EUR/100 km of the day
```

A period is the sum of its days, and its rate is this sum divided by its distance. A column
and the tile of the same period therefore show the same number, and the columns add up to
the tile.

In four weeks, the car charges and drives much more than one battery, so the change of the
battery content is a small error. A day in the past sits in the center of its window, so a
winter day keeps winter data. Four rules limit a window:

- It ends today. The rate of a recent day can change for 14 more days.
- It starts at the installation date.
- It stays inside the period of use of the car, so the rate of a new car holds no energy of
  the car before it.
- It needs 100 km and charged energy. Without them, the day has no rate and no driving
  cost. The tooltips of the driving cost and the rates name the kilometers of such days.

A window with a session without a cost has an energy rate, but no cost rate. The selection
"all" adds the cars, each with its own windows.

The margin of 14 days is a compromise. A shorter margin fixes a recent rate sooner and
keeps the season more exactly. A longer margin gives a steadier rate. Measured on 2,100
days of one car, with the change from the day before:

| Margin | Days without a rate | Median change | Change on 1 day in 10 |
| ------ | ------------------- | ------------- | --------------------- |
| ±7     | 3.6 %               | 7.8 %         | 30 % or more          |
| ±14    | 0.2 %               | 3.8 %         | 15 % or more          |
| ±30    | 0 %                 | 1.7 %         | 7 % or more           |

The days around the period need a summary and a detection too, so the car page builds them
before it shows the period (`Car::Report.pending_days`).

### Rejected designs

- An energy balance with the battery content. `car_range` cannot give the content, because
  kilometers to kWh needs the consumption, which is the result. `car_battery_soc` ×
  capacity works for a year but not for a day: the rate changed by 24 % from day to day in
  the median, and some days got a negative rate. It also needs a charge loss factor that
  the user does not know.
- One window for a period: the period plus the margin. The day columns of a month then had
  other windows than the tile and did not add up to it.
- A margin of 30 days. A recent rate changed for 30 days, and a winter month used November
  to March.
- A window that moves back near today to keep its length. The last 14 days then had the
  same window, and all columns of the current month were equal.
- `EUR/kWh` of the period × `kWh/100 km` of the window. A day that charges cheap PV energy
  then gets a low cost, also when the car drove on grid energy.

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
| `car_location`                                               | `CarLocation`   | no columns, a map of the places (see [Location](#location))  |

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
wallbox (`CarChargingPower`) and the cost of the wallbox (`WallboxCosts`). With the power
splitter, the curve splits into PV and grid, like the columns. Without the power splitter,
a day has no chart of the charging cost. The rates and the driving cost come from the daily
summaries, so a day has none of their charts.

A day stacks the offsite sessions of the selected cars on the curve of the wallbox. An
offsite session has no power curve, so the state of charge and the plug of its car tell
when it charged (`ChargingSession::OffsiteProfile`).

A day draws the distance since midnight as a line, interpolated like the daily summary
(see [Distance](#distance)). The line therefore ends at the distance on the driving card.

A rate column without a day with a rate has a gap. A column that the installation date,
today or the edge of a range cuts is hatched.

Each chart shows its insights below it (`Car::Insights`): the value of the timeframe, the
change against the previous month and the previous year, and the day with the highest
value.

These rules are decisions:

- A day does not split the curve of the wallbox by car. With one car, the split curve is
  almost the curve of the wallbox. With more cars, the list of the charging sessions shows
  the car of each session.
- The distance has no split by energy source. The source of the energy belongs to the
  charge, not to the drive.

## The car page

The navigation shows `/cars` when `Setting.enable_car` is true, which is the default.
Without a sponsorship, the page shows an offer (feature `:car`). The page shows its stats
when a car has an odometer, because the driving cost and the two rates depend on it. A
wallbox without a car shows a note that names the missing variables, and the detection
writes its sessions without a car. A car without a wallbox shows its distance and its
offsite sessions, and the guest badge and the wallbox badge are hidden, not zero.

The car page has no hours view, because its numbers come from full days. An hours
timeframe goes to today.

### The selection of the car

With more than one car, a select in the header of the page chooses one car or "all". The
select applies to the numbers and to the chart. The address has the car in front of the
page (`/cars/2/car_charging/2025`). The lists of the charging sessions and of the visits do
the same. Each link of the car page keeps the car, and a link to another page does not get
it. Without the car in the address, the page shows "all".

A timeframe offers only the cars in use in it. With one car in the timeframe, "all" is that
car, so the select shows that car and does not open. An installation with one car has no
select. A car that the page does not offer redirects to "all". The chart menu never names a
car, because the select above it chooses the car.

The selection "all" is the sum of the cars, and not the sum of the wallbox. A wallbox
session without a car counts for no car, because no car drove that energy. When the period
has such a session, "all" names its energy and links to the list with the filter "not
assigned". A number that is too small without a reason is the one error this page must not
make.

### The live view

The live view shows each car in use today, also when the page has a selected car, so it has
no select. Each car has its name as a badge in its color, a gauge of its range, filled to
the state of charge, its odometer and the time of its latest reading. The time is
necessary, because a car sensor holds its value at any age. For the admin, the gauge also
shows the place of the car.

The gauge shows the plug of the car (`car_connected_<n>`) and the charging power. Only the
car at the wallbox shows the power of the wallbox (`Car::Live`). When no car is at the
wallbox, the live view shows the power below the cars, for example for a guest.

### A period

A period shows two cards, charging on the left and driving on the right, like the source
and the usage of the power balance. A phone shows one card and a switch between the two,
and a cookie keeps the choice.

- Charging: the charged energy and a ring of its sources: PV, grid and offsite. The center
  of the ring shows the PV share. Without the power splitter, the ring shows the wallbox
  and offsite. Below, the number of wallbox, offsite and guest sessions.
- Driving: the distance with the average for each day. Below it, the driving cost and its
  rate per 100 km side by side, and then the consumption per 100 km and the average maximum
  range side by side. Below, the number of visits and places.

Each value opens its chart, and its tooltip explains it. The tooltip of the ring gives the
share and the cost of each source, and the charging cost. The driving cost gives its
calculation. The two rates give the rule of the 14 days and no calculation, because a
calculation of the rate from the driving cost is circular.

These rules are decisions:

- The driving cost stands on the card. The charging cost stands only in the tooltip of the
  ring. Over a long period the two are almost equal, so the card shows only one of them.
- The cost of a guest session is not a part of the charging cost. The tooltip of the ring
  shows it on a line of its own, as paid for guests.
- The costs show no red, because red marks a low cost as bad.
- The maximum range comes from the battery, but it tells how far a car can drive, so it
  stands with the driving. Its row stays for "all" with "–", so the layout does not change.
- The badges show also a count of 0, so the layout stays the same.
- No tooltip says that a recent rate can still change. Such a note confused more than it
  helped.

A selected car without an odometer has no driving, so the page shows the charging card
alone. A car with an odometer and without a value in the period shows the driving card with
"–". A period without a car in use shows "No car was in use in the selected period."

## Location

`car_latitude_<n>` and `car_longitude_<n>` give the location of a car. The location is
personal data, so only the admin sees it. The definitions declare `personal`:

- A guest gets no value of the sensors. The map of the car page shows a guest no places and
  a note that it is for the admin.
- The lists of the visits and the places and the tooltips of the places ask a guest to log
  in. The driving card still shows a guest the number of visits and places.
- The MCP server does not offer the sensors.

A position needs the latitude and the longitude with the same time. InfluxDB has no type
for a point, so the collector must write the two fields in one point, for example from one
JSON message. A reading with one of the two fields alone is no position.

The live view shows the place of each car. A click on the place opens the latest location
on a map that fills the window. A map in the live view took too much space beside the
gauge, and a place says enough at a glance.

A period shows the chart `car_location`: a circle for each place of the selected cars. The
area of a circle shows the share of the time that the cars spent at that place. Each point
has one color, also for a single car, because the color of a car marks the car and not its
places. One circle for each car and place was the other choice, but then the visits in the
tooltip of a car did not match the list of the visits of all cars.

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
A new home therefore resets the summaries (see
[When the detection runs](#when-the-detection-runs)).

### Address

The address comes from Nominatim, the geocoder of OpenStreetMap (`Place::Nominatim`). Its
[usage policy](https://operations.osmfoundation.org/policies/nominatim/) allows one request
per second and no periodic requests. So SOLECTRUS asks it only when the user asks for a
place:

- A click on the place of a car in the live view, or its badge without a name.
- The edit form of a place.
- The tooltip of a place on the map of a period.
- The edit form of an offsite session with a position and without an address.

A place asks once and keeps the answer. A location without a place gets no new place. The
build and the list of the sessions ask nothing, because the backfill asks for each charge
of the history.

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
