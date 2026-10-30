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

- The chart of the total timeframe can compare the years by month, quarter or season. Pick the comparison in the OVERALL menu. A dashed line shows the average of the years, and a period with missing days is hatched (#2131)
- The current timeframe tab opens a menu with its readings, for example "This month" and "Last 30 days"
- Prices: an electricity tariff can have a base fee for the grid connection. It is prorated by day and counts into the grid costs of the house (#2560)
- Electric vehicles: a new car page for up to five cars, with a live view, the distance, the charged energy, the costs for charging and driving, the consumption and the range. A day shows a timeline with the drives, the charges and the charge level. A charge at the wallbox shows its power over time, split into PV and grid. It lists the charging sessions at the wallbox and at public charging stations, and the places that the cars visited. Settings > Electric vehicles holds the cars and their places (#3517, #5836, #6021, #6022, #6035, #6053, #6057)
- Electric vehicles: each car sensor carries the number of its car, for example `INFLUX_SENSOR_CAR_BATTERY_SOC_1`. `INFLUX_SENSOR_CAR_BATTERY_SOC` without a number stays valid for the first car. New optional sensors give the odometer, the range, whether the car is plugged in, and its location
- Electric vehicles: the new page "EV vs. combustion car" compares the cost of the cars with a combustion car for the same distance, with and without the PV system. Settings > Electric vehicles takes the fuel, the consumption and the vehicle tax of the combustion car, and the running costs and incomes of the cars, for example the insurance or the GHG quota. The page and its settings show only when the weekly fuel prices exist and the currency is the euro. These prices come with a later update (#2407)

## Improvements

- A page that must calculate the daily summary of today or yesterday again shows its data sooner, without a spinner first
- The menu no longer has "Documentation". "About SOLECTRUS" opens the website, which links to it
- On a phone, small controls are easier to tap, and the labels of the key figures are larger
- On a phone, an info opens in a panel from the bottom. A long press on a bar of the balance opens its insights. Tooltips on desktop look lighter
- The insights (the light bulb next to the chart) show as lists, as on an iPhone, and contain all values of the tooltip. On a phone, the heatmap opens as a page of its own
- Without a sponsorship, the light bulb shows the total and the values of the tooltip
- On a phone, the settings open on a list of all sections, as on an iPhone. Before, a dropdown switched between them
- AI access: the price tool gives the unit for the rate per kWh alone, so an assistant does not read the base fee in that unit
- AI access: the charge level of the first car is now `car_battery_soc_1`. The old name `car_battery_soc` gets an error that names the new one
- Grid costs: the tooltip and the cost chart show the energy costs and the base fee separately (#2560)
- Settings on desktop: a click on a row opens the entry, and the "+" stands at the right of the tabs. The save button shows only after a change, with an "×" that discards it
- Settings: the prices and the payments no longer show an explanation above the list
- A form asks before you leave it with unsaved changes, by a link, a reload or by closing its dialog
- A question before an action, like a delete, shows in a dialog of the app instead of the box of the browser
- With more than one car in use, the power balance shows only the charge level of the home battery. With one car, it stays as before (#6020)
- The timeframe in the header is shorter. It no longer shows the years since commissioning or the first and last date of a week
- A tooltip of a live value stays open while the values refresh
- On a phone, the prices and the payments in the settings show as a list, as on an iPhone. An entry opens in a sheet over the list, as do the cars and the places
- On a phone, the forms of the settings look like the settings of an iPhone, with a switch for each option
- The loading bar shows only when a page takes longer than half a second
- The Top 10 has two buttons: one for the sensor, and one for the car, the calculation and the order
- On a phone, "More" opens a page of its own, as on an iPhone. Language, theme, color palette and fullscreen are switches there
- On a phone, a tap on a link clears the content at once, so you see that the tap works
- On a phone, the notifications show as a list, as on an iPhone. A dot marks an unread notification. "Understood" spans the width of the panel
- On a phone, the date with its arrows stands at the top of the page, below the tabs. A tap on it opens the calendar of its day, week, month or year, and the arrow back leads to the date selection. The lists of the car and the forecast have the same row. The arrows and a swipe change the page to the period before or after. On Now and Today, a swipe leads to yesterday and to the forecast. When you swipe, the page follows the finger and slides to the side, as on an iPhone
- On a phone, the car page opens the charging sessions and the places in a tall sheet. A tap on an entry opens its form in the same sheet. After a save, the sheet shows the list again. A link that leaves a form with unsaved changes asks first
- In the date selection, a tap on the day, week, month or year selects it. The arrow beside it opens the calendar for another one. On a phone, the date selection is shorter and fits without scrolling. The day, week, month, year, custom range and forecast are tiles in two columns. The hours, days and months back from now are one group, each with its unit. "All years" and "All months" stand under "Overall", above the year comparison
- Forms show an amount of money with at least two decimals, for example 13.90
- On a phone, a number field without negative values, like a price, opens the keypad of digits and the decimal separator
- Forecast: the temperature chart shows the highest and the lowest temperature of each day instead of the average
- An empty list or chart shows the same note everywhere: an icon, a title and a short text
- Settings > PV system > Cash flows: the form groups the categories by how they count in the amortization
- Settings > PV system > Cash flows: a click on the arrow beside a date shows the cash flows of that year alone
- Settings > PV system > Cash flows: each part of the filter has its own x that removes it
- The settings group by what they set up: PV system, Tariffs, Sensors, Electric vehicles and System. PV system holds the name of the system and its cash flows, and Tariffs holds the electricity price and the feed-in tariff. General is now System
- Escape now closes an open menu, like the options of the Top 10 or the selection of a chart
- The link to the main page now shows the power balance from every page, in the same timeframe. Before, it kept the topic of the previous page, for example the house consumption (#6055)
- Without HELIOS, the admin now also sees the menu item HELIOS. It opens the installation guide on the website

## Fixes

- AI access: a question about a past price now also gets the later changes of the tariff up to today. Before, they came as scheduled changes, and an assistant could claim that the old price still holds
- The menu item HELIOS now opens HELIOS at the address that HELIOS was last opened at, like the IP address in the home network. This needs the next version of HELIOS. Before, the menu item took the domain of the dashboard and opened a page that never loaded (#6092)
- A tooltip on a page that you scrolled down now opens next to its element. Before, it opened lower by the scroll distance
- On a phone, the bar at the bottom now stays in view on a long page. Before, it scrolled away
- On an iPhone, a tap on the selection of a chart or of the Top 10 no longer zooms into the page
- On a phone, two quick taps, like on an arrow of the timeframe, now count as two taps. Before, they could zoom into the page
- A sensor that tells whether a car is connected now reads "False", "OFF" and a negative number as not connected. Before, they counted as connected
- A browser tab that stays open for a long time now keeps its memory use low. Before, it grew with each page
- Settings: after a delete, the message now says "Deleted". Before, it said "Saved"
- Amortization: a payment of 100 million or more now shows an error at the amount. Before, the save failed with an error page
- Settings: an empty price or amount now shows one error. Before, it also said that the value is not a number
- On desktop, a page like the settings now scrolls as a whole, with the scroll bar at the edge of the window. Before, only the content below the header scrolled
- On desktop, a long page like the Top 10 now shows all of its content while you scroll. Before, a band at the top edge covered it
- Keyboard: the bar at the bottom of a phone screen now shows the focus. Before, the focus was invisible
- Screen readers: the GitHub link in the footer now has a name, and the author link reads a real dash. Before, it read "&mdash;"
- Screen readers now read a message after an action, like "Saved", and say which tab of the sensor settings is selected. Before, they kept silent
- A click with Cmd or Ctrl on a link that opens a dialog, like the timeframe, now only opens a new tab. Before, the page stayed dimmed

## Maintenance
