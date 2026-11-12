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

## Fixes

- **AI access:** the password page now refuses a callback address with a backslash or a user name. Before, such an address could show one host on the page and send the access to another
- **Code word page:** now refuses more guesses after ten wrong code words from one address within three minutes. Before, a trailing slash in the address lifted the limit
- **Names in tooltips and menus:** a sensor name with a character like `<` or `&` now shows as written. Before, the browser read it as HTML

## Maintenance

- Ruby 4.0.10 with security fixes for regular expressions and string case conversion, Alpine 3.24.4 with security fixes for OpenSSL, the PostgreSQL client and zlib
- Security updates for Rack and Puma
