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

- Prices: an electricity tariff can carry a base fee for the grid connection now. It is prorated by day, so a day, a week and a month each show the part that falls on it, and the grid costs contain it. The house costs carry the base fee. The costs of the heat pump, the wallbox and the other consumers do not, because they do not make the fee higher (#2560)

## Improvements

- AI access: in the price tool the unit belongs to the rate per kWh alone, so an assistant does not read a monthly base fee in that unit
- Grid costs: the tooltip names the energy costs and the base fee separately, so you see which part of the bill is fixed. The tooltip of the house splits its grid costs the same way (#2560)
- Settings: the lists of prices and payments show only the edit button. To delete an entry, open it and use the trash button in the form

## Fixes

## Maintenance
