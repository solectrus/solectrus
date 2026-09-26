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

## Improvements

- Resetting the summaries now also works when the database is damaged, for example by a failing SD card (#5952)
- The battery case temperature now shows blue for a normal temperature, and red only from about 45 °C. Before, all values from 40 °C were bright red. In dark mode, the colors of the case temperature and the heat pump tank temperature now match the other charts
- The sponsorship page now tells you how to close it: with "Maybe later", after you log in as administrator. An update no longer brings the page back
- On a phone, small controls are easier to tap: the period tabs, the arrows next to the date, the round chart buttons, the info icons, the buttons, the charge levels, "Source" and "Usage" below the balance, and the total of the inverter and house breakdown. The labels of the key figures and the "More" menu use a larger font
- On a phone, a tap or a long press on an info shows it in a panel that slides up from the bottom. The key figures, the date selection and the forms use the same panel. Swipe it down or tap beside it to close it. Tooltips on a computer have a new, lighter look
- In dark mode, red and green text is easier to read, for example amounts, trends and error messages. It has the color of the matching bar in the balance

## Fixes

- A donut chart in a low card, for example the COP on the heat pump page, now hides its ring and shows only the value in the center. Before, the ring stayed visible and left too little room for the value
- Buttons show the pointer cursor again, for example "Reset" for the summaries or "Save" in forms. Before, they showed the default arrow
- The amortization table now rounds the yearly cash flows correctly. Before, a year with many entries could be off by a few euros
- The values in a tooltip now add up to the total shown with them, in the charts as well, and the heating shares add up to 100 %. All values of a tooltip show the same number of decimals, for example 4,83 € + 10,20 € = 15,03 €. Before, each value was rounded on its own, so the total could be off by one in the last digit, for example 12 € + 3 € = 16 €
- A min/max bar with the same minimum and maximum now shows the exact value in its tooltip. Before, the value was 0,4 too high, for example 35,4 % instead of 35 %
- The tooltip of a min/max bar now shows both the minimum and the maximum again, for example 26,5 °C - 34,4 °C. Before, it showed the maximum only (#5953)
- The switches for the color scheme, the color palette and the table view of the house and inverter breakdown now work in a browser that blocks website data. Before, they did not respond there
- The summaries now reset themselves when you add a sensor that already has older data, or remove an inverter. Before, the history of such a sensor stayed empty until you reset the summaries yourself (#5959)
- On an iPhone, a tap on the selection of a chart or of the Top 10 no longer zooms into the page. Before, Safari enlarged the page and kept it enlarged after the selection

## Maintenance
