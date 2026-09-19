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

- SOLECTRUS now shows its own page when your device is offline, with a button to try again. You saw the error page of the browser before.

## Improvements

- The navigation bar and the timeframe tabs now react to a tap at once on a phone. Nothing happened for about half a second, until the new page arrived.
- The page appears sooner on a phone. The chart selector is also narrower and sits closer to its arrow.
- The icons now come from the server, as SVG in the page itself. JavaScript built them in the browser before, so they arrived a moment late and the page moved a little when they did.
- The text of a notification is now bigger on a phone, with more space between the lines.
- The installed app now shows its description in your language. It was always English before.
- A cancelled sponsorship now shows the days that are left. The status said "active" and named no end.
- On a phone, the sponsoring status now takes one line above the navigation bar. It took two lines below the color buttons.
- The chart menu now lists "Total consumption" under "Usage". It stood under "Other" before.

## Fixes

- The page opens in the theme and the sensor colors you picked. It started in the light theme with the standard colors. Pick your theme and your color palette again after this update, because the app cannot take over your old choice.
- The page opens in the dark theme right away when your system is set to dark and you follow it. It painted light first.
- The top of the app is sharp again when you open it from the home screen of an iPhone. iOS 26 and later painted a band of frosted glass over that edge. Add the app to your home screen again after this update, because iOS reads the setting only at that moment. (#5916)
- The month and day names in the charts now follow the language you picked in SOLECTRUS. They followed the language of the browser.
- Scrollbars and native form controls now follow the theme of the app, not the theme of the operating system.
- The Safari toolbar now keeps the color of the app header. The color was too light, and it changed with every reload and every page. It still needs a moment when you switch between the light and the dark theme.
- A chart tooltip now names the unit that fits the values it shows. A small value read "0 kW" when the chart reached above 1 kW, and now it reads "17 W". Values that stand in one tooltip still share one unit.
- The tooltip of the generation charts now says kW for large values. It always said W, so a value stood there as "7.164 W" instead of "7,2 kW".
- The tooltip for the savings now fits on a phone screen. Its text was too long and was cut off. (#5917)
- The tooltip of the main navigation stays calm when you click an item. It went away and appeared again twice.
- The menu no longer offers "Fullscreen" on an iPhone, where Safari has no fullscreen mode. A tap on it produced an error.

## Maintenance

- Updated to Ruby 4.0.7
