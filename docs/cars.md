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

The car page gives numbers that the wallbox data alone gives only with much manual work:

- What does the driving cost? The driving cost of a day, a month or a year.
- What do 100 km cost? The PV energy at the feed-in price, the grid energy at the
  electricity price and the offsite sessions, in `EUR/100 km`.
- How much energy does the car really use? The charged energy for each 100 km, with the
  charge losses, in `kWh/100 km`.
- What does the charging cost? The charging cost, split into PV, grid and offsite, without
  the guest sessions.
- How much energy went into the car? The charging sessions of the car at the wallbox and
  offsite.
- How do cost and consumption change in a year? A column for each month, with the same
  number as the tile of that month.
- How far does the car go on a full battery? The maximum range. It shows the loss of
  battery capacity and the season.

Each answer is for one car or for all cars together. The difficult part is the time
between charging and driving, because the car drives on energy of other days. The window
of 14 days before and after each day solves this (see
[A window for each day](#a-window-for-each-day)).

## Three layers

| Layer            | Says                            | Where it lives      |
| ---------------- | ------------------------------- | ------------------- |
| Wallbox          | how much energy flows, and when | `wallbox_*` sensors |
| Car _n_          | the state of one vehicle        | `car_*_<n>` sensors |
| Charging session | which car got which energy      | PostgreSQL record   |

A car sensor never carries energy, and a wallbox sensor never carries a vehicle. The
charging session is the only link. A daily sum cannot be split between vehicles, so the
session is the base of the energy and the cost of each car. A session also gives the PV
share at charge time, so a car that charges at night does not get the PV share of noon.

## Cars

A car has a number from 1 to `Sensor::Cars::MAX = 5`
([cars.rb](../app/lib/sensor/cars.rb)). The number names its sensors and its record in the
table `cars` ([car.rb](../app/models/car.rb)), so the sensors, the daily values and the
charging sessions of a number all name the same car.

The environment variables stay the source of the sensor configuration, because Helios
writes them. The car 2 reads `INFLUX_SENSOR_CAR_MILEAGE_2`,
`INFLUX_SENSOR_CAR_BATTERY_SOC_2` and `INFLUX_SENSOR_CAR_RANGE_2`. One of the three
variables is enough for a number. A number without a variable cannot get a car.
`INFLUX_SENSOR_CAR_BATTERY_SOC` is a permanent alias of `INFLUX_SENSOR_CAR_BATTERY_SOC_1`.
If both are set, the numbered variable wins with a warning.

The table `cars` holds what the environment cannot:

| Column         | Meaning                   | NULL means                                     |
| -------------- | ------------------------- | ---------------------------------------------- |
| `id`           | the number, no sequence   | –                                              |
| `name`         | the name of the car       | the name comes from I18n                       |
| `active_from`  | the first day of use      | – (required, by default the installation date) |
| `active_until` | the last day of use       | the car is in use                              |
| `color`        | a hex code like `#3b82f6` | the default color of the number                |

`Car::Provisioning` creates a car for each configured number on the first request that needs
one, so a user with one car has nothing to do. It is not part of `Sensor::Config`, because
a database write at configuration time couples the two layers.

The number of a car never changes, because the daily values store its history under the
sensor name with the number. SOLECTRUS never removes a car. A sold car keeps its number
and its history. The car management page (`/settings/cars`) edits the name, the period and
the color. It adds no car, because a configured number gets its car by itself.

### The name and the color of a car

The name of a car sensor is the car name plus the role: "Model Y (SOC)". A car without a
name gets "Car 2: Odometer" from I18n, so the name stays NULL and not a German string. The
settings page for sensor names lists no car sensor.

A car has a color for the views that show cars side by side: the badge of a charging
session, the select of the car, and the distance chart of all cars. The four sensors of a
car keep their own colors, because they have four meanings.

### A change of car

A car that replaces another car gets a new number and a period of use: the new car gets an
`active_from`, and the old car an `active_until` of the day before. A new car never writes
to an InfluxDB field of another car.

A change of a period changes the candidates of the wallbox sessions on the days between
the old and the new bound. The car therefore leaves its wallbox sessions outside its new
period, and the next build assigns them again. An offsite session has no detection, so the
model refuses a period that leaves an offsite session of the car outside.

A change of the variable of a number calls `Summary.reset!` and replaces its history. The
car management page says this.

## Sensors

| Sensor                 | Variable                            | Daily summary       | Meaning                      |
| ---------------------- | ----------------------------------- | ------------------- | ---------------------------- |
| `car_battery_soc_<n>`  | `INFLUX_SENSOR_CAR_BATTERY_SOC_<n>` | `min`, `max`, `avg` | state of charge (%)          |
| `car_mileage_<n>`      | `INFLUX_SENSOR_CAR_MILEAGE_<n>`     | `sum`               | odometer (km)                |
| `car_range_<n>`        | `INFLUX_SENSOR_CAR_RANGE_<n>`       | `avg`               | remaining range (km)         |
| `car_max_range_<n>`    | none, calculated                    | `avg`               | range at a full battery (km) |
| `car_charging`         | none, chart only                    | none                | charged energy               |
| `car_charging_costs`   | none, chart only                    | none                | charging cost                |
| `car_consumption_rate` | none, chart only                    | none                | `kWh/100 km`                 |
| `car_cost_rate`        | none, chart only                    | none                | `EUR/100 km`                 |
| `car_driving_costs`    | none, chart only                    | none                | driving cost                 |

The registry makes the four sensors of a car for each number up to `MAX`, and
`Sensor::Config` prunes a number without a configuration. The chart-only sensors have no
number: the car page gives them its selection of the cars (see
[The car page](#the-car-page)).

All car sensors need the permission `:car`. A car reports its state only while it is
online, so its sensors have a `max_age` of 2 hours. The rates and the driving cost exist
when a car has an odometer, because the energy and the cost can come from the offsite
sessions alone.

The power balance shows the state of charge of the first car with one beside the house
battery.

### Daily values

`car_battery_soc` is in the release v1.3.3. The migration
[add_cars](../db/migrate/20260927102209_add_cars.rb) renames it to `car_battery_soc_1`, so
its rows keep their data and no summary is reset.

A past day with a summary has no value of a new odometer, because an added sensor builds no
summary again. The changelog tells the user to reset the daily summaries after adding the
car sensors.

### Distance

`car_mileage_<n>` stores the distance of each day as the aggregation `sum`. A car writes
its odometer only while it is online, so a day can have one reading or none.
`Influx::DailyDiffs` therefore interpolates the odometer at each midnight between the
readings around it. The daily values then add up exactly: the sum of a range is
the odometer at its end minus the odometer at its start.

The definition marks the sensor as a meter (`meter: true`), so the summary build reads it
this way and not with the integral of a power. One Flux program gives the readings around
midnight for all meters and all days of a build.

### Maximum range

`car_max_range_<n>` is `car_range_<n> × 100 / car_battery_soc_<n>`. Its daily average
shows the loss of battery capacity and the season. The summary build calculates it from the
daily averages of `car_range` and `car_battery_soc`. An SQL query reads the stored average
and not the formula, because the formula over the averages of a period is not the average of
its days.

## Charging sessions

A charging session is a charge of a car ([charging_session.rb](../app/models/charging_session.rb)).
The kind says where the energy flowed, and it also gives the source:

| Kind      | Charged at              | Written by | Energy and cost from    |
| --------- | ----------------------- | ---------- | ----------------------- |
| `wallbox` | own wallbox             | detection  | wallbox curve, splitter |
| `offsite` | public or other wallbox | user       | manual input            |

A `wallbox` session is in one of three states:

| State        | `car_id` | `guest` | Counts for                 |
| ------------ | -------- | ------- | -------------------------- |
| car          | set      | false   | the car                    |
| guest        | NULL     | true    | no car, its cost is a loss |
| not assigned | NULL     | false   | no car, "all" names it     |

A guest charge is a decision of the user, and "not assigned" is an open task. An `offsite`
session always has a car and never the guest mark. A wallbox session stores its energy,
its grid share (`kwh_grid`), its cost and the cost of its grid share (`cost_grid`). The
user enters the energy and the cost of an offsite session.

A session belongs to the local date of its start. A charge at 23:30 therefore stays on the
day of the distance beside it. Only an offsite session can end on the next day, because
the detection splits a wallbox session at midnight. The list then shows the date of its
end beside the time.

The page `/charging_sessions` has a tab for each kind and a filter of the car: one car,
"all", and for the wallbox also "not assigned" and the guests. The user changes the car,
the guest mark and the note of a wallbox session. The detection writes its time, energy and
cost, so the form shows them read-only, and the list deletes only an offsite session. A new
session is always `offsite`, because a guest charge that no wallbox measured has no energy
and no cost.

### The detection

`ChargingSession::Detection` finds the wallbox sessions in the wallbox curve, as one more
step of the daily build ([detection.rb](../app/services/charging_session/detection.rb)):

- A session is a continuous period with `wallbox_power > 0`, found on the 5-minute means.
  A gap of 15 minutes or less does not end it, because load management and PV surplus
  control make such gaps.
- `wallbox_car_connected` bridges a longer gap, but it never moves an end. Otherwise a
  charge before the sensor reports the connection loses its energy.
- A session needs 0.1 kWh at least, because many wallboxes report a standby power.
- The energy comes from `integral(unit: 1h)` over the raw series, like the daily sum. The
  grid share comes from `wallbox_power_grid` in the same way.
- The grid share costs the electricity price and the PV share the feed-in price of the
  day. Without the power splitter, `kwh_grid` stays NULL, and the full energy gets the
  electricity price. Without a price, `cost` stays NULL, because zero is a wrong number.
- The cost of the grid share goes into `cost_grid`. The cost of the PV share is the rest
  of `cost`.

A day is the unit, so a charge over midnight becomes two sessions. The sessions of a day
nearly hold the wallbox energy of the day, and never more.

### Which car charged

The candidates of a wallbox session are the cars whose period holds its day
([car_assignment.rb](../app/services/charging_session/detection/car_assignment.rb)):

1. One candidate: that car.
2. More than one candidate: the car that the heuristics find.
3. Otherwise: not assigned.

Two cars cannot charge at the same time on one wallbox, so the heuristics use strong signs:
the state of charge of a car rises by 1 % or more during the session, or the odometer of a
car rises by more than 0.5 km during the session and excludes it. A reading counts only
within 2 hours of the session. Rule 1 never makes a guest. With one car, each session gets
this car, and the user marks a guest charge by hand.

### How the detection runs

SOLECTRUS has no background processing. A detected session comes from the InfluxDB data
of one day, like a daily summary, so the detection is a step of `Sensor::Summarizer`. The
build gives the rules for a missing and a stale day, the progress bar and the MCP path for
free. "Delete the summaries" builds the sessions again.

A fresh summary says nothing about the sessions, so the detection has its own mark:
`summaries.charging_sessions_version`. A day is pending when the mark is NULL or older
than `ChargingSession::Detection::VERSION`. Such a day gets the detection alone. The
migration leaves the mark NULL, which gives the backfill of an existing installation. The
backfill covers the full history, because the detection adds about 2 % to the build.

Only the pages that read the sessions wait for a pending day: the car page and the list of
the charging sessions. The other pages, the amortization and the MCP server count a day
only when its summary is missing or stale. So a new version of the detection builds no
day again for the power balance. The progress bar of a page sends this choice with each
chunk, so the chunk builds the days that the page counted.

A new build keeps the changes of the user. An existing session keeps its car when the
period of the car holds the day, and it keeps its guest mark and its note. A new build can
move a start. The old session then gives these changes to the new session that overlaps it
most. An offsite session is never touched.

### A change of a price

A wallbox session gets the prices of its day when the detection finds it. A change of a
price therefore marks the days of that price as pending: from its start to the day before
the next price of the same name, before and after the change. The car page then runs the
detection on these days again, and the summaries stay as they are.

The cost stays stored, and a page does not calculate it when it reads it. Dynamic prices
will change every 15 minutes and come from InfluxDB. The cost of a session then depends
on when its power flowed, so only the detection, which reads the power curve, can
calculate it. The daily summaries will need the same step, and a change of a dynamic
price will mark its days in the same way.

## Balance of a period

`Car::Balance` gives the numbers of the car page for a selection of cars
([balance.rb](../app/services/car/balance.rb)):

- Energy and cost: the sum of the charging sessions of the selected cars. A guest session
  and a session that is not assigned count for no car.
- Distance: the sum of the daily distances of the selected cars.
- Maximum range: the average of one car. The cars of "all" have batteries of their own.

`Car::ChargeSplit` splits the energy and the cost into PV, grid and offsite. A wallbox
session stores the cost of its grid share, so the split reads no price.

## Rates and driving cost

### A window for each day

The battery sits between charging and driving. If the car charges 50 kWh on Monday and
drives on it for a week, Monday alone gives 500 kWh/100 km and each other day 0.

Each day therefore takes its rates from a window: the day plus 14 days before and after it
([daily_rates.rb](../app/services/car/daily_rates.rb)).

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
- It stays inside the period of use of the car, so the rate of a new car holds no energy
  of the car before it.
- It needs 100 km and charged energy. Without them, the day has no rate and no driving
  cost. The tooltips of the driving cost and the rates name the kilometers of such days
  (`Car::UnratedNote`).

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
before it shows the period.

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
for the next days. Over a long period the two numbers come close.

A cost is a sum, and a rate is not. The user interface must never add a rate.

## Charts

| Chart                                   | Columns                                                                                             |
| --------------------------------------- | --------------------------------------------------------------------------------------------------- |
| `car_charging`, `car_charging_costs`    | sessions of the selected cars, stacked into PV, grid and offsite                                    |
| `car_consumption_rate`, `car_cost_rate` | sum of the days of the column ÷ their distance                                                      |
| `car_driving_costs`                     | sum of the days of the column                                                                       |
| `car_mileage_<n>`                       | distance of the column, without a split (see [Distance without a split](#distance-without-a-split)) |
| `car_range_<n>`                         | now, hours and a day only, because the range of a day depends on the charge                         |

A week and a month have a column for each day, a year for each month, and all for each
year. A session belongs to a full day, so now, the hours view and a day show the power
curve and the cost of the wallbox alone in the charts `car_charging` and
`car_charging_costs`. The distance, the rates and the driving cost come from the daily
summaries, so now, the hours view and a day have none of their charts, and their values
open no chart there. A column without a day with a rate has a gap. A column that the
installation date, today or the edge of a range cuts is hatched.

The tooltip of a rate column and a driving cost column says that each day takes the rate of
the 14 days before and after it. The driving cost column shows the calculation
(distance × EUR/100 km) first.

In the selection "all", the distance chart stacks a column for each car in the color of the
car.

## Distance without a split

The page and the distance chart show the distance without a split by energy source. The
source of the energy belongs to the charge, not to the drive. The charges of one day say
nothing about the energy that a drive on that day uses. Only the charged energy and the
charging cost split into PV, grid and offsite.

## The car page

The navigation shows `/cars` when `Setting.enable_car` is true, which is the default.
Without a sponsorship, the page shows an offer (feature `:car`). The page shows its stats
when a car has an odometer, because the driving cost and the two rates depend on it. A
wallbox without a car shows a note that names the missing variables, and the detection
writes its sessions without a car. A car without a wallbox shows its distance and its
offsite sessions, and the guest badge and the wallbox pills are hidden, not zero.

### The selection of the car

With more than one car, a select on the page chooses one car or "all". The car is a
parameter (`?car=2`, see `CarSelectable`), and each link of the page keeps it. Without the
parameter, the page shows "all". With one car, "all" is that car and there is no select.
The chart menu offers the sensors of the selected car, and in "all" the sensors of each car
and the distance one time.

The selection "all" is the sum of the cars, and not the sum of the wallbox. A wallbox
session without a car counts for no car, because no car drove that energy. When the period
has such a session, "all" names its energy and links to the list with the filter "not
assigned". A number that is too small without a reason is the one error this page must not
make.

### The live view

The live view shows the charging power and the plug of the wallbox one time. Below them
each selected car has a gauge of its range, filled to the state of charge, and its
odometer. The charging power and the gauge open their chart. The odometer opens none,
because the distance chart needs a day at least.

### A period

A period shows two cards, charging on the left and driving on the right, like the source
and the usage of the power balance:

- Charging: the charged energy, split into offsite, grid and PV. At the bottom the
  charging cost, the average maximum range of one car and the number of guest and offsite
  sessions.
- Driving: the distance with the average for each day, the driving cost and the two rates.

Each value opens its chart. The tooltips explain each number: the calculation of the
driving cost and the rates, the rule of the 14 days, and the parts of the charging cost.

These rules are decisions:

- The driving cost and the charging cost stand in different cards with their own title, so
  that nobody takes one for the other. Both stay for each period, so the layout stays the
  same.
- The maximum range describes the battery, so it stands with the charging.
- The badges show also a count of 0, so the layout stays the same.
- No tooltip says that a recent rate can still change. Such a note confused more than it
  helped.

Without a distance, the page shows "No driving data available for the selected period."
The hours view always shows it, because it does not query the odometer.

## MCP

The numbered sensors `car_battery_soc_<n>`, `car_mileage_<n>` and `car_max_range_<n>`
reach MCP as all sensors do. The chart-only sensors, for example `car_cost_rate`, have no
number and no selection of a car, so MCP has no tool for the rates of one car.
