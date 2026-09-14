<!--
Release notes for the next release. Add a line in the SAME commit that makes the
change. The release skill takes this file, translates it, and empties it again.

What goes in: a change a user can see or feel. Not dependency bumps,
refactorings, tests, CI, lint fixes. Reverted before the release? Delete the line.

How to write it: one line, English, the words of the user interface. Name what
changed for the user, not how it was built. Add "(#5886)" when an issue or a
discussion drove the change. Under "Fixes", write what works now, and name
what went wrong before, so a reader knows the bug.

Keep every section, an empty one included.
-->

## New features

## Improvements

- Amortization: the hint about a still uncertain prognosis is now a warning sign next to the sliders, so the key figures stay clean
- Balance sheet: if the two columns do not add up to the same energy, a sign between them names the difference, what it means for your sensors, and what it does to your savings (#5890)
- Mobile navigation: an unread notification shows a red dot on the "More" button
- Notifications: the dialog and the list have a cleaner look
- AI access: an assistant knows your sensors, names the time of the daily peak, and answers what it can when a sensor is missing
- AI access: a callback address with `http` is accepted now, not only `https`, so a client from a local network, such as Open WebUI, can connect (#5880)
- Heat pump: the tooltip of the consumption tile shows the exact values and the total, as the power balance does (#5903)
- Login: if HELIOS is running, the password hint names the place in HELIOS instead of the `.env` file
- Loading bar: in dark mode it is less bright, and it stays hidden for short page changes

## Fixes

- Notifications: if you are not signed in, the red mark now leads to a page that explains why only the operator can read a message, instead of a forbidden page
- Logout: if you sign out on a page that is open to everyone, you now stay on that page, instead of landing on the home page
- Amortization: the "Return" tab now shows its chart icon instead of a placeholder, and says that the curve needs more than one year of history
- Lock screen: the unlock page now follows dark mode, instead of staying bright
- AI access: the consent page now shows the callback host the way the browser reads it, instead of leaving the escapes visible
- Power balance: on a phone the tooltip of a segment is now narrower and puts the value under its label, instead of running off the screen (#5886)
- Daily summaries: building them for a long timeframe now stays on the page and finishes, instead of ending on an empty page
- Pages: a section now loads again by itself, for example when you come back to a tab after hours, instead of hanging on its loading spinner

## Maintenance

- Lock screen: the cookie migration from versions before 1.2.0 is removed
- Dependencies updated
