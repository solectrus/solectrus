import { Controller } from '@hotwired/stimulus';
import { isReducedMotion } from '@/utils/device';

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
//
// With `slide`, the marking moves from the tab it leaves to the one it lands
// on, as the segmented control of iOS. It starts with the tap. Turbo can
// render twice, a preview and then the page, and each render replaces the
// bar. A slide under way then goes on in the new bar from where it is. The
// pills of a wide screen in landscape do not slide. `looks` are the looks of
// the labels in their order, on their way from the old ones to the new ones.
type Look = { color: string; fontWeight: string };

let slideFrom: { left: number; width: number; looks: Look[] } | null = null;
const pills = window.matchMedia(
  '(min-width: 64rem) and (orientation: landscape)',
);

const DURATION = 250;
const EASING = 'cubic-bezier(0.32, 0.72, 0, 1)';

export default class extends Controller<HTMLElement> {
  static values = { slide: Boolean };
  declare readonly slideValue: boolean;

  declare undo: (() => void) | null;
  declare pending: string | null;
  declare marking: HTMLElement | null;
  declare endSlide: (() => void) | null;

  // The labels of the new bar start from the looks they had in the bar it
  // replaces, and go on to their own. Only the bar that slides takes the
  // slide over: a page can hold a hidden bar too, like the tabs of the
  // desktop, which connects first. settle() drops a slide nobody took.
  connect() {
    this.forget();

    const marked = this.marked();
    if (slideFrom && marked && this.slides()) {
      const { looks } = slideFrom;
      const undress = this.dress(
        this.items().map((element, index): [HTMLElement, Look | undefined] => [
          element,
          looks[index],
        ]),
      );
      this.slide(slideFrom, marked, undress);
      slideFrom = null;
    }
  }

  // The undo closure holds both items. Let them go with the navigation that
  // replaces them, so nothing keeps a detached element alive.
  disconnect() {
    this.forget();
  }

  // The items are the children of the bar. An item may hold a menu of its own,
  // and the links in there are not items: marking one would dress it as a tab
  // and dress the tapped tab as a menu entry, which is a different size.
  //
  // An item that opens a menu is a button rather than a link, so it carries no
  // class list to swap with a link. With `slide`, the two trade the looks of
  // their labels instead. Without it, the bar waits for the page like it did
  // before.
  markCurrent(event: Event) {
    const target = (event.target as Element | null)?.closest?.('a[href]');
    if (
      !(target instanceof HTMLAnchorElement) ||
      target.parentElement !== this.element
    )
      return;

    const marked = this.marked();
    if (!marked || marked === target) return;

    const slides = this.slides();
    const current = this.element.querySelector(':scope > a[aria-current]');
    if (!current && !slides) return;

    this.pending = target.href;
    if (!slides) {
      this.undo = this.swap(current!, target);
      return;
    }

    // A second tap takes the marking from where the first one has moved it
    const from = this.offset(this.marking ?? marked);
    const markedLook = this.look(marked);
    const targetLook = this.look(target);

    const unswap = current ? this.swap(current, target) : null;
    this.undo = () => {
      this.endSlide?.();
      unswap?.();
    };
    if (current) {
      const undress = this.dress([
        [marked, markedLook],
        [target, targetLook],
      ]);
      this.slide(from, target, undress);
    } else {
      const restyle = () =>
        this.dress([
          [marked, targetLook],
          [target, markedLook],
        ]);
      this.slide(from, target, restyle, marked);
    }
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
    slideFrom = null;
  }

  // Only a slide under way goes on in the next bar. One that has arrived
  // leaves the marking where the next bar has it anyway.
  handoff() {
    const moving = this.marking
      ?.getAnimations()
      .some((animation) => animation.playState === 'running');
    if (moving)
      slideFrom = {
        ...this.offset(this.marking!),
        looks: this.items().map((element) => this.look(element)),
      };
  }

  // Whether the marking slides here and now. Without a slide, a tab with a
  // menu keeps its look until the page arrives, as a label of the same color
  // as the marking would vanish on it.
  private slides() {
    return (
      this.slideValue &&
      !pills.matches &&
      !isReducedMotion() &&
      this.element.checkVisibility()
    );
  }

  private forget() {
    this.undo = null;
    this.pending = null;
  }

  // The labels of the bar in their order: the links, and the button of a tab
  // with a menu
  private items() {
    return [
      ...this.element.querySelectorAll<HTMLElement>(
        ':scope > a, :scope > * > [aria-haspopup]',
      ),
    ];
  }

  // The element that wears the marking: the current link, or the button of
  // the current tab that opens a menu
  private marked() {
    return this.element.querySelector<HTMLElement>(
      ':scope > a[aria-current], :scope > * > [aria-haspopup]',
    );
  }

  // The box of an element within the bar. The button of a tab with a menu lies
  // in a wrapper of its own, so its offsetTop would not count from the bar.
  private offset(element: Element) {
    const rect = element.getBoundingClientRect();
    const bar = this.element.getBoundingClientRect();
    return {
      left: rect.left - bar.left,
      top: rect.top - bar.top,
      width: rect.width,
      height: rect.height,
    };
  }

  // A copy of the marking of `source` moves below the labels to `to`. The
  // labels stay where they are. A tab that wears the marking itself shows it
  // again at the end. A link that takes over from a tab with a menu does not,
  // so there the copy stays until the page replaces the bar.
  //
  // `restyle` runs once the labels transition. It takes away the look they
  // had when the slide started, or gives them their new look and returns its
  // undo for the end. The labels change from the one look to the other in the
  // time and the curve of the slide. A label that kept its look until the end
  // would stand in the color of the marking as soon as the marking is below
  // it, which the curve brings there early.
  private slide(
    from: { left: number; width: number },
    to: HTMLElement,
    restyle: () => (() => void) | void,
    source = to,
  ) {
    this.endSlide?.();
    const target = this.offset(to);
    const style = getComputedStyle(source);
    const marking = document.createElement('div');
    Object.assign(marking.style, {
      position: 'absolute',
      margin: '0',
      pointerEvents: 'none',
      top: `${target.top}px`,
      height: `${target.height}px`,
      backgroundColor: style.backgroundColor,
      borderRadius: style.borderRadius,
      boxShadow: style.boxShadow,
    });
    this.element.prepend(marking);
    this.marking = marking;

    const hidden = source === to ? [to] : [to, source];
    hidden.forEach((element) => {
      element.style.backgroundColor = 'transparent';
      element.style.boxShadow = 'none';
    });

    // Opacity stays in the list, so the fade of a tapped label goes on rather
    // than jump to its end
    const items = this.items();
    items.forEach((element) => {
      element.style.transition = `color ${DURATION}ms ${EASING}, font-weight ${DURATION}ms ${EASING}, opacity ${DURATION}ms ${EASING}`;
    });
    // The transition starts from the look the labels have now
    items.forEach((element) => getComputedStyle(element).color);
    let undoLabels = restyle();

    const end = () => {
      marking.remove();
      hidden.forEach((element) => {
        element.style.removeProperty('background-color');
        element.style.removeProperty('box-shadow');
      });
      items.forEach((element) => element.style.removeProperty('transition'));
      undoLabels?.();
      undoLabels = undefined;
      if (this.marking === marking) this.marking = null;
      if (this.endSlide === end) this.endSlide = null;
    };
    this.endSlide = end;

    marking
      .animate(
        [
          { left: `${from.left}px`, width: `${from.width}px` },
          { left: `${target.left}px`, width: `${target.width}px` },
        ],
        { duration: DURATION, easing: EASING, fill: 'forwards' },
      )
      .finished.then(() => source === to && end(), end);
  }

  private look(element: HTMLElement) {
    const { color, fontWeight } = getComputedStyle(element);
    return { color, fontWeight };
  }

  // Gives labels a look of another state, and returns its undo
  private dress(pairs: [HTMLElement, Look | undefined][]) {
    pairs.forEach(([element, look]) => Object.assign(element.style, look));

    return () => {
      pairs.forEach(([element]) => {
        element.style.removeProperty('color');
        element.style.removeProperty('font-weight');
      });
    };
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
