<!--
Release notes for the next release. Add a line in the SAME commit that makes the
change. The release skill takes this file, translates it, and empties it again.

What goes in: a change a user can see or feel. Not dependency bumps,
refactorings, tests, CI, lint fixes. Reverted before the release? Delete the
line. A bug that arose after the last release gets no line either, because no
user has seen it. To tell the two apart, run `git tag --contains <sha>` on the
commit that caused the bug. An empty result means that no release carries it.

How to write it: one line, English, the words of the user interface. Name what
changed for the user, not how it was built. Add "(#5886)" when an issue or a
discussion drove the change. Under "Fixes", write what works now, and name
what went wrong before, so a reader knows the bug.

Keep every section, an empty one included.
-->

## New features

- An amber dot at the HELIOS menu item and at the button that opens the menu shows when HELIOS needs your attention: the configuration is incomplete, or the services wait for a restart or fail
- Electric vehicle: a new page shows the distance driven, the charged energy, the charging and driving costs, the usage and the driving cost per 100 km, and the maximum range, for each car or for all cars together. SOLECTRUS finds the charging sessions in the power curve of your wallbox and assigns each one to a car. The list of charging sessions shows the PV share of each session at the wallbox. In this list, an admin can mark a session as a guest charge, assign it to another car, and enter charging sessions at public charging stations. Settings > Cars gives each car a name, a period of use and a color. Up to five cars are possible: the page needs the new sensors `INFLUX_SENSOR_CAR_MILEAGE_1` and `INFLUX_SENSOR_CAR_RANGE_1` (and `_2` to `_5` for more cars). `INFLUX_SENSOR_CAR_BATTERY_SOC` stays valid for the first car. After you add the sensors, reset the daily summaries in Settings > General, so the page also shows the past days (#3517, #5836)

## Improvements

- In dark mode, the warning color for a low battery level or a medium autarky is now a lighter amber, so it is easier to tell apart from red
- The codeword page now answers with HTTP status 403, so bots and crawlers see that the site is locked (#5974)

## Fixes

- The charge level of the car battery now shows the same colors as the home battery and the autarky. Before, its green was too dark in dark mode (#5976)

## Maintenance
