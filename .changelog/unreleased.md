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

- SOLECTRUS now tells you when your device cannot reach it. You saw the error page of the browser before, which does not say which app failed. The page comes in your language and offers to try again.

## Improvements

- The app description that your device shows for the installed app now uses your language. It was always English before.
- A cancelled sponsorship now shows the days that are left. The status said that the sponsorship is active and named no end, so the last day came without warning.
- The sponsoring status in the menu of a phone now takes one line, with its two texts at the left and the right edge, and it sits directly above the navigation bar. It took two lines and stood in the empty space below the color buttons. The texts are shorter there, and the box drops the explanation next to a button, because the button already says what you can do. The sidebar on a large screen keeps the layout and the texts it had.
- The text of a notification is now easier to read on a phone. It was 14px there and 16px on a large screen, and the lines sat closer together than they do now.
- The page appears sooner on a phone. The app measured the width of the chart selector before it painted anything, and that measurement held the first picture back. The selector also sits closer to its arrow now, because the old measurement made it too wide.
- The navigation bar and the timeframe tabs answer a tap at once on a phone. The marker moves to the item you tapped, and the item gets smaller while your finger is on it. Nothing happened for about half a second before, until the new page arrived.
- The icons now arrive with the page. The browser had to build all 60 of them on every page you opened, which took work away from the rest of the page and made the icons jump into place a moment late. The app also sends 33 kB less to your browser.

## Fixes

- The month and day names in the charts now use the language you picked in SOLECTRUS. They followed the language of the browser, so a German app showed "Jan, Feb, Mar" when the browser was set to English.
- The top of the app is sharp again when you open it from the home screen of an iPhone. iOS 26 and later paint a band of frosted glass over that edge, and it made the connection status behind it look blurred. The band also stayed on Essentials, Notifications and Settings, and it is gone there too. Add the app to your home screen again after this update, because iOS reads the setting only at that moment. (#5916)
- The tooltip for the savings now fits on a phone screen. Its title and its explanation were too long, so the text was cut off. (#5917)
- The Safari toolbar now has the same color as the app header, and keeps it while you move through the app. The color was too light, and it changed with every reload and with every page you opened. It still needs a moment to follow when you switch between the light and the dark theme.
- The page opens in the theme and the sensor colors you picked. It started in the light theme with the standard colors and switched over once the browser had read your choice. Pick your theme and your color palette again after this update, because the app now keeps both in a different place.
- The page opens in the dark theme right away when your system is set to dark and you follow it. It painted light first and turned dark a moment later.
- Scrollbars and native form controls now follow the theme of the app. They followed the theme of the operating system before.

## Maintenance

- Updated to Ruby 4.0.7
