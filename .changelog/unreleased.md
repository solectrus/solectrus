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

- The chart of the total timeframe can now compare the years month by month, quarter by quarter, or season by season. Pick "Months across the years", "Quarters across the years" or "Seasons across the years" in the OVERALL menu to turn the comparison on, and the chart then fills the whole width. A period that stands on fewer days than it has is drawn hatched: the one that is still running, and the first one, if your records start after its first day. Click a bar to open that period. A dashed line across each group of bars shows the average of the years, so you see at once which bars are above it. It counts complete periods only, and it needs at least two of them. A season runs over three months, winter from December to February, and it counts into the year it begins in. (#2131)
- The timeframe tabs now name what they can show. The current tab opens a menu with its readings, for example "This month" and "Last 30 days", or "This year", "Last 12 months" and "Last 365 days". You reached these by clicking the tab again before, which nothing told you.
- Prices: an electricity tariff can carry a base fee for the grid connection now. It is prorated by day, so a day, a week and a month each show the part that falls on it, and the grid costs contain it. The house costs carry the base fee. The costs of the heat pump, the wallbox and the other consumers do not, because they do not make the fee higher (#2560)
- Electric vehicles: a new car page shows the distance, the charged energy and the costs for charging and driving. It also shows the usage, the driving cost per 100 km and the maximum range, for each car or for all cars together. Like the other charts, each chart compares a period with the previous month and the previous year. The distance, the charged energy and the driving cost also show the day with the highest value. Settings > Electric vehicles gives each car a name, a short name, a period of use and a color (#3517, #5836)
- Electric vehicles: up to five cars are possible. Each sensor of a car has a variable with the number of the car, for example `INFLUX_SENSOR_CAR_ODOMETER_1` (`_2` to `_5` for more cars). With the charge level alone, the car page shows the car and its charging. The odometer adds the distance and the driving costs, and `INFLUX_SENSOR_CAR_RANGE_1` adds the range. A variable without a number, for example `INFLUX_SENSOR_CAR_BATTERY_SOC`, stays valid for the first car. After you add the sensors, the next start builds the daily summaries again, so the page also shows the past days
- Electric vehicles: SOLECTRUS finds the charging sessions in the power curve of the wallbox and assigns each one to a car. The menu links to the list of charging sessions, which shows the PV share of each session. An admin can mark a session as a guest charge, assign it to another car, or add a session at a public charging station. A new detection keeps these changes
- Electric vehicles: the optional sensor `INFLUX_SENSOR_CAR_CONNECTED_1` tells whether a car is plugged in. The live view shows it, and SOLECTRUS uses it to assign the charging sessions. The live view shows the charging power of the wallbox at the car that is plugged in at home
- Electric vehicles: the live view keeps the values of a car until the car reports again, and shows the time of the latest reading. This helps for a car that sleeps or a source that sends only changes, for example TeslaMate
- Electric vehicles: the optional sensors `INFLUX_SENSOR_CAR_LATITUDE_1` and `INFLUX_SENSOR_CAR_LONGITUDE_1` give the location of a car, which only the admin sees. The live view shows where each car is and opens a map. The chart menu of a period opens a map of the places where the cars stood, with the time at each place
- Electric vehicles: Settings > Electric vehicles > Locations lists these places. You can give each place a name, for example "Office", and mark one place as home, where your wallbox is. SOLECTRUS then assigns a charging session at the wallbox only to a car at home. A place that was never visited, for example from wrong positions that you corrected later, shows as such in the list and can be deleted (#6022)
- Electric vehicles: the Visits page lists when a car arrived at a place and when it left. The driving card of the car page counts the visits and locations of a period, and opens their list or the map
- Electric vehicles: offsite charging sessions that you did not enter now show up as unconfirmed sessions, found from the rise of the charge level of a car away from home. This needs the odometer or the location of the car. You confirm such a session with its cost, or dismiss it. An unconfirmed session does not count until you confirm it. The car filter of the list can show the unconfirmed sessions alone, and there "Dismiss all" dismisses all unconfirmed sessions of the timeframe at once, for example of a time without receipts (#6021)
- Electric vehicles: Settings > Electric vehicles takes the battery capacity of a car. It estimates the energy of a proposed charging session. The list of charging sessions shows the charge level at the start and at the end of each session, also of a session you entered. With the capacity, the form of a session also shows the charging loss

## Improvements

- The menu no longer has an entry "Documentation". "About SOLECTRUS" opens the website, which links to the documentation
- On a phone, small controls are easier to tap: the period tabs, the arrows next to the date, the round chart buttons, the info icons, the buttons, the charge levels, "Source" and "Usage" below the balance, and the total of the inverter and house breakdown. The labels of the key figures and the "More" menu use a larger font
- On a phone, a tap or a long press on an info shows it in a panel that slides up from the bottom. The key figures, the date selection and the forms use the same panel. Swipe it down or tap beside it to close it. A long press on a bar of the balance or on a key figure of the heat pump opens its insights, the same panel as the light bulb next to the chart. For the current values, for a key figure of the balance and for the forecast, the panel shows the details as a list, with the label on the left and the value on the right, and it names the selected period. Tooltips on a computer have a new, lighter look
- The insights of a sensor (the light bulb next to the chart) now show as lists, as on an iPhone: the total at the top, then groups for the comparison with earlier periods and for the daily values. A comparison names the earlier period and its value. A row that leads to another period shows an arrow. On a phone, the heatmap is a page of its own, which a tap on its row opens. There the heatmap of a year stands upright, shows all twelve months and uses the full height
- The insights now show everything that the tooltip of a bar shows: the share from photovoltaics for the battery charging and for a consumer on the house page, the costs of a consumer, the CO₂ reduction for the generation, the grid import costs for the grid import and the feed-in revenue for the feed-in. The heat pump also shows its energy from photovoltaics and from the grid, and its costs split into grid import costs and lost feed-in revenue
- Without a sponsorship, the light bulb next to the chart now also shows the total and the values of the tooltip, above the note on the insights
- On a phone, the settings now open on a list of all sections, as on an iPhone. A tap on a row opens the section, and the round arrow at the top left leads back to the list. The pages slide in and out to the side. The sensors show their groups (generators, consumers, battery) as a list of the same kind. Before, a dropdown at the top switched between the sections
- AI access: in the price tool the unit belongs to the rate per kWh alone, so an assistant does not read a monthly base fee in that unit
- AI access: the charge level of the first car is now `car_battery_soc_1`, and `_2` to `_5` for more cars. A request with the old name `car_battery_soc` gets an error that names the new one
- Grid costs: the tooltip names the energy costs and the base fee separately, and the cost chart stacks the two, so you see which part of the bill is fixed. The tooltip of the house splits its grid costs the same way (#2560)
- Settings: on a computer, a click anywhere on a row of the prices, the payments, the electric vehicles or the locations opens the entry. The rows have no buttons. To delete an entry, open it and use the trash button in the form
- Settings: on a computer, the "+" for a new price or payment now stands at the right of the tabs, where a phone has it too. Before, a large round button stood above the list
- With more than one car in use, the power balance shows only the charge level of the home battery, as a round badge. The charge levels of the cars are on the car page. With one car in use, the balance shows the charge level of the car and whether it is connected, as before (#6020)
- The timeframe in the header takes less space: "Since commissioning" no longer shows how many years ago that was, and a week or a timeframe like "Last 7 days" no longer shows its first and last date
- A tooltip of a live value stays open while you read it. Before, the next refresh of the values closed it
- On a phone, the electricity price, the feed-in tariff and the payments in the settings now show as a list, as on an iPhone, with the note of each entry below its date. A tap on an entry opens it on a page of its own, which slides in from the right. The check mark at the top right saves it, and a red line below the fields deletes it. The round "+" at the top right adds an entry. The electric vehicles and their locations follow the same pattern, and the locations open from a row below the vehicles. The computer keeps the table
- On a phone, the forms of the settings look like the settings of an iPhone: white groups on a gray page, the label of each field at the left and its value at the right, and a switch for each option. The round check mark at the top right saves the form. It lights up once you change a field. In the sensors, the pages to show in the navigation stand in a group of their own, each with its name alone
- The loading bar at the top of the page now shows only when a page takes longer than half a second. Before, it showed on almost every change of page, often only for a moment
- On a phone, the content goes away as soon as you tap a link, until the next page is there. So you see at once that the tap works. When the page takes longer to load, a spinner appears after half a second
- On a phone, a small arrow next to the timeframe in the header shows that a tap on it opens the date selection
- On a phone, the period tabs now stand above the date and look like a segmented control of an iPhone: the selected period has a white segment that slides to the tab you tap, and a tapped tab dims instead of shrinking. The date is white. On a computer too, the arrows beside the date are now double arrows, so they differ from the back button of a page, and the live status is a light pill whose text is no longer in capitals
- Forms show an amount of money with at least two decimals, for example 13.90 instead of 13.9, and the currency after the value

## Fixes

- On an iPhone, a tap on the selection of a chart or of the Top 10 no longer zooms into the page. Before, Safari enlarged the page and kept it enlarged after the selection
- A sensor that tells whether a car is connected now shows "No" for a text like "False" or "OFF" and for a negative number, which some collectors send for an error. Before, the live view showed such a value as connected
- A browser tab that stays open for a long time now keeps its memory use low. Before, each page you opened stayed in memory, so the app used more memory with each click and could become slow
- Settings: after you delete a price or a payment, the message now says "Deleted". Before, it said "Saved"

## Maintenance
