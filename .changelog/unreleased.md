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
- The chart of the total timeframe can now compare the years month by month, quarter by quarter, or season by season. Pick "Months across the years", "Quarters across the years" or "Seasons across the years" in the OVERALL menu to turn the comparison on, and the chart then fills the whole width. A period that stands on fewer days than it has is drawn hatched: the one that is still running, and the first one, if your records start after its first day. Click a bar to open that period. A dashed line across each group of bars shows the average of the years, so you see at once which bars are above it. It counts complete periods only, and it needs at least two of them. A season runs over three months, winter from December to February, and it counts into the year it begins in. (#2131)
- The timeframe tabs now name what they can show. The current tab opens a menu with its readings, for example "This month" and "Last 30 days", or "This year", "Last 12 months" and "Last 365 days". You reached these by clicking the tab again before, which nothing told you.
- Prices: an electricity tariff can carry a base fee for the grid connection now. It is prorated by day, so a day, a week and a month each show the part that falls on it, and the grid costs contain it. The house costs carry the base fee. The costs of the heat pump, the wallbox and the other consumers do not, because they do not make the fee higher (#2560)

## Improvements

- In dark mode, the warning color for a low battery level or a medium autarky is now a lighter amber, so it is easier to tell apart from red
- The codeword page now answers with HTTP status 403, so bots and crawlers see that the site is locked (#5974)
- Each page loads faster, because the server no longer builds an unused text of the navigation, which took up to 100 ms
- On a phone, small controls are easier to tap: the period tabs, the arrows next to the date, the round chart buttons, the info icons, the buttons, the charge levels, "Source" and "Usage" below the balance, and the total of the inverter and house breakdown. The labels of the key figures and the "More" menu use a larger font
- On a phone, a tap or a long press on an info shows it in a panel that slides up from the bottom. The key figures, the date selection and the forms use the same panel. Swipe it down or tap beside it to close it. A long press on a bar of the balance or on a key figure of the heat pump opens its insights, the same panel as the light bulb next to the chart. For the current values, for a key figure of the balance and for the forecast, the panel shows the details as a list, with the label on the left and the value on the right, and it names the selected period. Tooltips on a computer have a new, lighter look
- The insights of a sensor (the light bulb next to the chart) now show as lists, as on an iPhone: the total at the top, then groups for the comparison with earlier periods and for the daily values. A comparison names the earlier period and its value. A row that leads to another period shows an arrow. On a phone, the heatmap is a page of its own, which a tap on its row opens. There the heatmap of a year stands upright, shows all twelve months and uses the full height
- The insights now show everything that the tooltip of a bar shows: the share from photovoltaics for the battery charging and for a consumer on the house page, the costs of a consumer, the CO₂ reduction for the generation, the grid import costs for the grid import and the feed-in revenue for the feed-in. The heat pump also shows its energy from photovoltaics and from the grid, and its costs split into grid import costs and lost feed-in revenue
- Without a sponsorship, the light bulb next to the chart now also shows the total and the values of the tooltip, above the note on the insights
- On a phone, the settings now open on a list of all sections, as on an iPhone. A tap on a row opens the section, and the round arrow at the top left leads back to the list. The pages slide in and out to the side. The sensors show their groups (generators, consumers, battery) as a list of the same kind. Before, a dropdown at the top switched between the sections
- Resetting the summaries now also works when the database is damaged, for example by a failing SD card (#5952)
- The battery case temperature now shows blue for a normal temperature, and red only from about 45 °C. Before, all values from 40 °C were bright red. In dark mode, the colors of the case temperature and the heat pump tank temperature now match the other charts
- The sponsorship page now tells you how to close it: with "Maybe later", after you log in as administrator. An update no longer brings the page back
- In dark mode, red and green text is easier to read, for example amounts, trends and error messages. It has the color of the matching bar in the balance
- AI access: in the price tool the unit belongs to the rate per kWh alone, so an assistant does not read a monthly base fee in that unit
- Grid costs: the tooltip names the energy costs and the base fee separately, and the cost chart stacks the two, so you see which part of the bill is fixed. The tooltip of the house splits its grid costs the same way (#2560)
- Settings: the lists of prices and payments show only the edit button. To delete an entry, open it and use the trash button in the form

## Fixes

- The live chart of the heat pump power now continues with the measured power. Before, it dropped to zero while the heat pump produced no heat
- The charge level of the car battery now shows the same colors as the home battery and the autarky. Before, its green was too dark in dark mode (#5976)
- The selection of the timeframe now opens also when the browser sends no referrer. Before, it failed with a server error
- When you return to the browser tab, the stats and the chart now load again only once, and only for a period that can still change. Before, each return loaded them again, often twice
- On an iPhone, a tap on the selection of a chart or of the Top 10 no longer zooms into the page. Before, Safari enlarged the page and kept it enlarged after the selection

## Maintenance
