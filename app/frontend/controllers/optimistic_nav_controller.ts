import { Controller } from '@hotwired/stimulus';

// Moves the "current" marking of a navigation to the tapped item at once,
// instead of waiting for the page it points to.
//
// A tap on a nav item is answered by nothing until Turbo renders the response.
// That is 200ms on a fast connection and clearly more on a phone, and for all
// of it the navigation still highlights the page the user is leaving. Moving
// the marking on `turbo:click` closes that gap: the bar reacts in the same
// frame as the touch, the way a native tab bar does, and the loading happens
// behind an interface that has already answered.
//
// The classes stay where they belong - in the template. This swaps the class
// lists of the two items rather than naming any of them, so what an active
// item looks like is never repeated here. Elements inside an item that change
// with the state as well (a pill, a dot) are marked `data-nav-state` and are
// swapped along with it, in document order.
//
// A failed navigation puts everything back. A successful one ends in a render
// that carries the server's own marking, so nothing here has to be undone.
export default class extends Controller {
  declare undo: (() => void) | null;
  declare pending: string | null;

  connect() {
    this.forget();
  }

  // The undo closure holds both items. Let them go with the navigation that
  // replaces them, so nothing keeps a detached element alive.
  disconnect() {
    this.forget();
  }

  markCurrent(event: Event) {
    const target = (event.target as Element | null)?.closest?.('a[href]');
    if (!target) return;

    const current = this.element.querySelector('a[aria-current]');
    if (!current || current === target) return;

    this.undo = this.swap(current, target);
    this.pending = (target as HTMLAnchorElement).href;
  }

  // Frames fetch on their own, and a chart that fails to load says nothing
  // about the page the user is on their way to. So undo the marking only for
  // the request this navigation started.
  restore(event: Event) {
    const failed = (event as CustomEvent).detail?.request?.url;
    if (failed && this.pending && String(failed) !== this.pending) return;

    this.undo?.();
    this.forget();
  }

  // A rendered page carries the marking of the server, so the undo of the
  // navigation that brought it has nothing left to put back. Drop it, rather
  // than hold two items a morph may have replaced in the meantime.
  settle() {
    this.forget();
  }

  private forget() {
    this.undo = null;
    this.pending = null;
  }

  private swap(from: Element, to: Element) {
    const pairs: [Element, Element][] = [[from, to]];

    const fromParts = from.querySelectorAll('[data-nav-state]');
    const toParts = to.querySelectorAll('[data-nav-state]');
    fromParts.forEach((part, index) => {
      const counterpart = toParts[index];
      if (counterpart) pairs.push([part, counterpart]);
    });

    const before = pairs.map(([a, b]) => [a.className, b.className]);
    const currentValue = from.getAttribute('aria-current');

    pairs.forEach(([a, b]) => {
      const classes = a.className;
      a.className = b.className;
      b.className = classes;
    });

    from.removeAttribute('aria-current');
    if (currentValue) to.setAttribute('aria-current', currentValue);

    return () => {
      pairs.forEach(([a, b], index) => {
        [a.className, b.className] = before[index];
      });

      to.removeAttribute('aria-current');
      if (currentValue) from.setAttribute('aria-current', currentValue);
    };
  }
}
