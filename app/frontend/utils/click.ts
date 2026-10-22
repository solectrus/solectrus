// A click with a modifier or with the middle button opens a link in a new tab
// or window, so a handler that loads the link itself leaves such a click to
// the browser
export function isModifiedClick(event: Event): boolean {
  return (
    event instanceof MouseEvent &&
    (event.metaKey ||
      event.ctrlKey ||
      event.shiftKey ||
      event.altKey ||
      event.button === 1)
  );
}
