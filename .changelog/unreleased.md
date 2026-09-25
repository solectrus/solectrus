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

- Resetting the summaries now also works when the database is damaged, for example by a failing SD card (#5952)

## Fixes

- Buttons show the pointer cursor again, for example "Reset" for the summaries or "Save" in forms. Before, they showed the default arrow
- The amortization table now rounds the yearly cash flows correctly. Before, a year with many entries could be off by a few euros

## Maintenance
