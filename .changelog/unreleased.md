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
- Electric vehicles: a new car page shows the distance, the charged energy and the costs for charging and driving. It also shows the usage, the driving cost per 100 km and the maximum range, for each car or for all cars together. Like the other charts, each chart compares a period with the previous month and the previous year. The distance, the charged energy and the driving cost also show the day with the highest value. Settings > Electric vehicles gives each car a name, a short name, a period of use and a color (#3517, #5836)
- Electric vehicles: up to five cars are possible. Each car needs the sensors `INFLUX_SENSOR_CAR_ODOMETER_1` and `INFLUX_SENSOR_CAR_RANGE_1` (`_2` to `_5` for more cars). A variable without a number, for example `INFLUX_SENSOR_CAR_BATTERY_SOC`, stays valid for the first car. After you add the sensors, SOLECTRUS builds the daily summaries again at the next start, so the page also shows the past days
- Electric vehicles: SOLECTRUS finds the charging sessions in the power curve of the wallbox and assigns each one to a car. The menu links to the list of charging sessions, which shows the PV share of each session. An admin can mark a session as a guest charge, assign it to another car, or add a session at a public charging station. A new detection keeps these changes
- Electric vehicles: the optional sensor `INFLUX_SENSOR_CAR_CONNECTED_1` tells whether a car is plugged in. The live view shows it, and SOLECTRUS uses it to assign the charging sessions. The live view shows the charging power of the wallbox at the car that is plugged in at home
- Electric vehicles: the live view keeps the values of a car until the car reports again, and shows the time of the latest reading. This helps for a car that sleeps or a source that sends only changes, for example TeslaMate
- Electric vehicles: the optional sensors `INFLUX_SENSOR_CAR_LATITUDE_1` and `INFLUX_SENSOR_CAR_LONGITUDE_1` give the location of a car, which only the admin sees. The live view shows where each car is and opens a map. The chart menu of a period opens a map of the places where the cars stood, with the time at each place
- Electric vehicles: Settings > Electric vehicles > Locations lists these places. You can give each place a name, for example "Office", and mark one place as home, where your wallbox is. SOLECTRUS then assigns a charging session at the wallbox only to a car at home
- Electric vehicles: the Visits page lists when a car arrived at a place and when it left. The driving card of the car page counts the visits and locations of a period, and opens their list or the map

## Improvements

- In dark mode, the warning color for a low battery level or a medium autarky is now a lighter amber, so it is easier to tell apart from red
- The codeword page now answers with HTTP status 403, so bots and crawlers see that the site is locked (#5974)
- Each page loads faster, because the server no longer builds an unused text of the navigation, which took up to 100 ms
- The power balance shows only the charge level of the home battery again, as a round badge. The charge level of the car is now on the car page
- The timeframe in the header takes less space: "Since commissioning" no longer shows how many years ago that was, and a week or a timeframe like "Last 7 days" no longer shows its first and last date
- A tooltip of a live value stays open while you read it. Before, the next refresh of the values closed it

## Fixes

- The live chart of the heat pump power now continues with the measured power. Before, it dropped to zero while the heat pump produced no heat
- The charge level of the car battery now shows the same colors as the home battery and the autarky. Before, its green was too dark in dark mode (#5976)
- A round badge at 0 %, for example an empty battery, now shows an empty ring. Before, a dot stayed at its top
- The selection of the timeframe now opens also when the browser sends no referrer. Before, it failed with a server error
- When you return to the browser tab, the stats and the chart now load again only once, and only for a period that can still change. Before, each return loaded them again, often twice
- A sensor that tells whether a car is connected now shows "No" for a text like "False" or "OFF" and for a negative number, which some collectors send for an error. Before, the live view showed such a value as connected

## Maintenance
