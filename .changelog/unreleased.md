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
- Resetting the summaries now also works when the database is damaged, for example by a failing SD card (#5952)
- The battery case temperature now shows blue for a normal temperature, and red only from about 45 °C. Before, all values from 40 °C were bright red. In dark mode, the colors of the case temperature and the heat pump tank temperature now match the other charts
- The sponsorship page now tells you how to close it: with "Maybe later", after you log in as administrator. An update no longer brings the page back
- In dark mode, red and green text is easier to read, for example amounts, trends and error messages. It has the color of the matching bar in the balance
- Settings: the lists of prices and payments show only the edit button. To delete an entry, open it and use the trash button in the form

## Fixes

- The charge level of the car battery now shows the same colors as the home battery and the autarky. Before, its green was too dark in dark mode (#5976)

## Maintenance
