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

## Improvements

- In dark mode, the warning color for a low battery level or a medium autarky is now a lighter amber, so it is easier to tell apart from red
- The codeword page now answers with HTTP status 403, so bots and crawlers see that the site is locked (#5974)
- Each page loads faster, because the server no longer builds an unused text of the navigation, which took up to 100 ms
- On a phone, small controls are easier to tap: the period tabs, the arrows next to the date, the round chart buttons, the info icons, the buttons, the charge levels, "Source" and "Usage" below the balance, and the total of the inverter and house breakdown. The labels of the key figures and the "More" menu use a larger font
- On a phone, a tap or a long press on an info shows it in a panel that slides up from the bottom. The key figures, the date selection and the forms use the same panel. Swipe it down or tap beside it to close it. A long press on a bar of the balance opens the insights of the bar, the same panel as the light bulb next to the chart. For the current values, for a key figure of the balance and for the forecast, the panel shows the details as a list, with the label on the left and the value on the right, and it names the selected period. Tooltips on a computer have a new, lighter look
- The insights of a sensor (the light bulb next to the chart) now show as lists, as on an iPhone: the total at the top, then groups for the comparison with earlier periods and for the daily values. A comparison names the earlier period and its value. A row that leads to another period shows an arrow. On a phone, the heatmap is a page of its own, which a tap on its row opens. There the heatmap of a year stands upright, shows all twelve months and uses the full height
- The insights now show everything that the tooltip of a bar shows: the share from photovoltaics for the battery charging and for a consumer on the house page, the costs of a consumer, the CO₂ reduction for the generation, the grid import costs for the grid import and the feed-in revenue for the feed-in
- Without a sponsorship, the light bulb next to the chart now also shows the total and the values of the tooltip, above the note on the insights

## Fixes

- The live chart of the heat pump power now continues with the measured power. Before, it dropped to zero while the heat pump produced no heat
- The charge level of the car battery now shows the same colors as the home battery and the autarky. Before, its green was too dark in dark mode (#5976)
- A round badge at 0 %, for example an empty battery, now shows an empty ring. Before, a dot stayed at its top
- The selection of the timeframe now opens also when the browser sends no referrer. Before, it failed with a server error
- When you return to the browser tab, the stats and the chart now load again only once, and only for a period that can still change. Before, each return loaded them again, often twice
- On an iPhone, a tap on the selection of a chart or of the Top 10 no longer zooms into the page. Before, Safari enlarged the page and kept it enlarged after the selection

## Maintenance
