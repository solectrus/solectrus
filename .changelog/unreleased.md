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

## Before you update

- The Docker container stops at once when it runs as root. If your `compose.yaml` sets `user: root` or `user: "0"`, remove that line.
- The Docker container starts only with `RAILS_ENV=production`, which the image sets by itself. If your `compose.yaml` or `.env` sets `RAILS_ENV`, remove it.

## New features

## Improvements

### Speed

- The navigation bar and the timeframe tabs mark your tap at once on a phone, which feels snappier. Before, the mark came only with the new page, a quarter of a second later.
- A page appears sooner on a phone. Before, the app measured the chart selector first, and that held the page back. The selector is also narrower now.
- The icons come as inline SVG with the page. Before, the browser built them afterwards, so they came late and the layout jumped.

### Other

- The chart menu lists "Total consumption" under "Usage". Before, it stood under "Other".
- A notification uses the text size of the rest of the page on a phone, with more space between the lines. Before, it was the smallest text on the screen.
- The installed app shows its description in your language. Before, it was English for everyone.
- SOLECTRUS shows a page of its own when your device cannot reach it, with a button to try again. Before, you saw the error page of the browser, which names no app.

## Fixes

- The page opens in the theme and the sensor colors you picked, and follows your system theme from the first paint. Before, it flashed light.
- A chart tooltip uses the unit that fits its own values. Before, a small value read "0 kW", and the generation charts read "7.164 W" instead of "7,2 kW". Lines in one tooltip still share one unit.
- The month and day names in the charts follow the language you picked in SOLECTRUS. Before, they followed the language of the browser.
- The top of the app is sharp again on the home screen of an iPhone. Before, iOS 26 and later painted frosted glass over that edge. Add the app to your home screen again, because iOS reads the setting only at that moment. (#5916)
- The installed app shows the SOLECTRUS logo while it starts on an iPhone 14 Pro or newer. Before, the screen stayed blank. Add the app to your home screen again, because iOS reads the start screen only at that moment.
- The menu no longer offers "Fullscreen" on an iPhone. Before, a tap on it produced an error, because Safari has no fullscreen mode there.
- The Safari toolbar keeps the color of the app header. Before, it was too light and changed with every page. A theme switch still takes a moment.
- Scrollbars and native form controls follow the theme of the app. Before, they stayed light in the dark app.
- The tooltip for the savings fits on a phone screen. Before, its text was cut off. (#5917)
- The tooltip of the main navigation no longer flickers on a click. Before, it went away and appeared again twice.

## Maintenance

- Updated to Ruby 4.0.7
