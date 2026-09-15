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

- The app description that your device shows for the installed app now uses your language. It was always English before.

## Fixes

- The top of the app is sharp again when you open it from the home screen of an iPhone. iOS 26 and later paint a band of frosted glass over that edge, and it made the connection status behind it look blurred. The band also stayed on Essentials, Notifications and Settings, and it is gone there too. Add the app to your home screen again after this update, because iOS reads the setting only at that moment. (#5916)
- The tooltip for the savings now fits on a phone screen. Its title and its explanation were too long, so the text was cut off. (#5917)
- The Safari toolbar now has the same color as the app header, and keeps it while you move through the app. The color was too light, and it changed with every reload and with every page you opened. It still needs a moment to follow when you switch between the light and the dark theme.
- The page opens in the theme and the sensor colors you picked. It started in the light theme with the standard colors and switched over once the browser had read your choice. Pick your theme and your color palette again after this update, because the app now keeps both in a different place.
- The page opens in the dark theme right away when your system is set to dark and you follow it. It painted light first and turned dark a moment later.
- Scrollbars and native form controls now follow the theme of the app. They followed the theme of the operating system before.

## Maintenance
