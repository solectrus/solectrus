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

### Electric vehicles

- **Car page:** up to five cars, with live view, distance, charged energy, costs, consumption and range. A day shows a timeline of the drives, the charges and the charge level (#3517, #5836, #6021, #6022, #6035, #6053, #6057)
- **Charging sessions and places:** lists of the charges at the wallbox and at public stations, and of the places that the cars visited. A charge at the wallbox shows its power, split into PV and grid
- **EV vs. combustion car:** compares the costs with a combustion car for the same distance, with and without PV. The car page shows the savings below its figures. Needs the euro as currency and the fuel prices of the Public Data Collector, which HELIOS sets up in an EU country (#2407)
- **Settings > Electric vehicles:** the cars, their places, the combustion car for the comparison, and running costs and incomes like the insurance or the GHG quota
- **Sensors:** each car sensor has a number, for example `INFLUX_SENSOR_CAR_BATTERY_SOC_1`. Without a number, it means the first car. New optional sensors: odometer, range, plugged in, location
- **AI access:** a new tool gives the distance, the charging costs and the driving costs per 100 km of the cars, and the savings against a combustion car

### More

- **Year comparison:** the chart of the total timeframe compares the years by month, quarter or season, with the average as a dashed line. Pick it in the OVERALL menu (#2131)
- **Base fee:** an electricity tariff can have a base fee for the grid connection. It counts into the grid costs, prorated by day. The AI access gives it too (#2560)
- **Timeframe menu:** the tab of the current timeframe offers readings like "This month" or "Last 30 days"
- **AI access:** two new tools read the raw InfluxDB data, also the other measurements in the same bucket that no sensor reads. They stay off until the admin allows raw data in the system settings

## Improvements

### Navigation

- **Main page:** the link always opens the power balance, in the same timeframe. Before, it kept the topic of the last page (#6055)
- **Menu:** "Documentation" is gone, "About SOLECTRUS" leads to it. Without HELIOS, the admin sees the item HELIOS with the installation guide
- **Header:** the timeframe is shorter, without the years since commissioning or the dates of a week
- **Date selection:** a tap selects the day, week, month or year, the arrow opens the calendar. "All years" and "All months" moved under "Overall"
- **Top 10:** two buttons, one for the sensor and one for car, calculation and order
- **Escape:** closes an open menu
- **Loading bar:** shows only after half a second

### Phone

- **More:** a page of its own, with switches for language, theme, color palette and fullscreen
- **Date:** stands below the tabs and opens the calendar. Arrows or a swipe change the period, and the page follows the finger. On Now and Today, a swipe leads to yesterday or to the forecast
- **Settings:** open on a list of all sections, with a switch for each option. Prices, payments, cars and places open an entry in a tall sheet
- **Notifications:** a list, with a dot on each unread one
- **Info:** opens in a panel from the bottom. A long press on a bar of the balance opens its insights
- **Controls:** small controls are easier to tap, and the labels of the key figures are larger. A tap on a link clears the content at once
- **Number fields:** a field like a price opens the keypad of digits

### Charts and display

- **Insights:** the light bulb next to the chart shows all values of the tooltip as a list. On a phone, the heatmap is a page of its own. Without a sponsorship, it shows the total and the values of the tooltip
- **Tooltips:** a lighter look on desktop, and long words break by syllable. A tooltip of a live value stays open while the values refresh
- **Empty state:** an empty list or chart shows the same note everywhere
- **Forecast:** the temperature chart shows the high and the low of each day instead of the average
- **Live view:** the bars glide to a new value in 0.3 instead of 1 second, which takes the device less work
- **Electric vehicles:** the live view shows "On the road" as soon as the charge level falls. With more than one car, the balance shows only the home battery (#6020)
- **Desktop:** a page is as high as its content and glides to its new height on a page change

### Settings and forms

- **Sections:** PV system, Tariffs, Sensors, Electric vehicles and System, which was General
- **Desktop:** a click on a row opens the entry. The save button shows only after a change, with an "×" that discards it
- **Cash flows:** grouped by year, and a click on a year filters for it. The form groups the categories by how they count in the amortization
- **Unsaved changes:** a form asks before you leave it
- **Questions:** a question before an action, like a delete, shows in a dialog of the app instead of the browser
- **Amounts:** money shows at least two decimals, for example 13.90

### Speed

- **Daily summaries:** calculate in about a fifth less time. A bar shows the progress and the time left
- **Long timeframes:** charts and figures, like the amortization, calculate in about half the time
- **Today and yesterday:** a page that must calculate their summary again shows its data sooner
- **Amortization:** a new interest rate shows its figures at once

## Fixes

- **Live view:** now keeps its update every few seconds. Before, it sometimes stopped or slowed to once a minute, for example after a return to the browser tab or a short outage of the values
- **Open for a long time:** a page like on a wall display now needs less memory and less work of the device. Before, the memory grew with each page, and the browser redrew the page without need
- **HELIOS link:** now opens HELIOS at the address that it was last opened at, with HELIOS 1.6. Before, it took the domain of the dashboard and never loaded (#6092)
- **AI access:** a past price now comes with the later changes of the tariff, and a ranking names the date of the first place. Before, an assistant sometimes named an old price or a wrong day
- **Feed-in limit:** the warning icon now hides in a small segment. Before, it was cut off
- **Car connected:** "False", "OFF" and negative values now count as not connected. Before, they counted as connected
- **Phone tab bar:** now stays in view on a long page. Before, it scrolled away
- **Zoom:** the page now keeps its size after two quick taps or, on an iPhone, a tap on a chart selection. Before, it zoomed in
- **Tooltips:** now open next to their element on a scrolled page. Before, they opened lower by the scroll distance
- **Desktop scrolling:** a page like the settings now scrolls as a whole. Before, only the content below the header scrolled
- **Cmd or Ctrl click:** on a link to a dialog, it now only opens a new tab. Before, the page stayed dimmed
- **Accessibility:** the phone tab bar now shows the keyboard focus, and screen readers read messages like "Saved" and the selected tab. Before, the focus was invisible and the screen reader kept silent
- **Settings:** a delete now says "Deleted", and an empty price shows one error. Before, it said "Saved" and showed two errors
- **Amortization:** a payment of 100 million or more now shows an error. Before, the save failed with an error page
- **Battery icon:** a charge level at a step like 15 %, 30 % or 60.5 % now shows the matching level. Before, it showed a full battery

## Maintenance
