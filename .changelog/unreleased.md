<!--
Release notes for the next release. Add a line in the SAME commit that makes the
change. The release skill takes this file, translates it, and empties it again.

What goes in: a change a user can see or feel. Not dependency bumps,
refactorings, tests, CI, lint fixes. Reverted before the release? Delete the line.

How to write it: one line, English, the words of the user interface. Name what
changed for the user, not how it was built. Add "(#5886)" when an issue or a
discussion drove the change. Under "Fixes", write what works now, never what was
broken.

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

## Fixes

- Notifications: if you are not signed in, the red mark now leads to a page that says why you cannot read the message, and that the mark stays until the operator logs in
- Logout: a page that is open to everyone keeps you on that page after a logout, instead of sending you to the home page
- Amortization: while the "Return" tab waits for data, it shows its chart icon and says that a history needs more than one year
- Lock screen: the unlock page now follows dark mode
- AI access: the consent page now shows the callback host the way the browser reads it, with escapes resolved
- Power balance: on a phone the tooltip of a segment is now narrower and puts the value under its label, so it stays inside the screen (#5886)
- A section that hangs on its loading spinner now loads again by itself, for example when you come back to a tab after hours

## Maintenance

- Lock screen: the cookie migration from versions before 1.2.0 is removed
- Dependencies updated
