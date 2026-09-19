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
- The chart of the total timeframe can now compare the years month by month, quarter by quarter, or season by season. Pick "Months across the years", "Quarters across the years" or "Seasons across the years" in the OVERALL menu to turn the comparison on, and the chart then fills the whole width. A period that stands on fewer days than it has is drawn hatched: the one that is still running, and the first one, if your records start after its first day. Click a bar to open that period. A season runs over three months, winter from December to February, and it counts into the year it begins in. (#2131)
- The timeframe tabs now name what they can show. The current tab opens a menu with its readings, for example "This month" and "Last 30 days", or "This year", "Last 12 months" and "Last 365 days". You reached these by clicking the tab again before, which nothing told you.

## Improvements

- In dark mode, the warning color for a low battery level or a medium autarky is now a lighter amber, so it is easier to tell apart from red
- The codeword page now answers with HTTP status 403, so bots and crawlers see that the site is locked (#5974)

## Fixes

- The charge level of the car battery now shows the same colors as the home battery and the autarky. Before, its green was too dark in dark mode (#5976)

## Maintenance
