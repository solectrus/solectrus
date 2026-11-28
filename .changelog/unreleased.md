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

- A consumer that is excluded from the house consumption now has a lighter shade of the house color, the same in the balance sheet and in the charts. If several consumers are excluded, each one gets its own shade (#6243).

## Fixes

- The map of the car locations now explains when the browser cannot display it, for example without hardware acceleration. Before, its box stayed empty.
- The tooltip of the power balance chart now always lists the consumers that are excluded from the house consumption. Before, it left out such a consumer if it had used no power when the chart was loaded (#6243).

## Maintenance
