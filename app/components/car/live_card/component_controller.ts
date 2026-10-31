import { Controller } from '@hotwired/stimulus';

import { isReducedMotion } from '@/utils/device';
import { EASE_QUICK } from '@/utils/motion';

// A card of the live view that folds its list (see Car::LiveCard::Component):
// a tap on the folded cell unfolds the list in its place, and a tap on the
// last cell of the list folds it again. With the keyboard, the focus moves to
// the cell that takes the place of the pressed one. The box grows or shrinks
// to its new height, unless the user asks for less motion. The map shows
// once the box has grown.
//
// The live view refreshes by a morph, which would fold the card again and
// empty the frame of the map. So the card keeps its state through it, and the
// map stays while its address stays. A move of the car changes the address,
// and the map loads again.

export default class extends Controller<HTMLElement> {
  static readonly targets = ['toggle', 'map', 'box'];

  declare readonly toggleTargets: HTMLElement[];
  declare readonly hasMapTarget: boolean;
  declare readonly mapTarget: HTMLElement;
  declare readonly boxTarget: HTMLElement;

  private resize: Animation | null = null;

  toggle(event: Event) {
    const from = this.boxTarget.getBoundingClientRect().height;
    const open = this.element.dataset.open !== 'true';
    this.element.dataset.open = String(open);
    this.animateBox(from, open);

    // Only a keyboard needs the focus on the other cell, a tap would show
    // its ring
    const tapped = event.currentTarget as HTMLElement;
    const keyboard = tapped.matches(':focus-visible');
    for (const toggle of this.toggleTargets) {
      toggle.setAttribute('aria-expanded', String(open));
      if (keyboard && toggle !== tapped) toggle.focus({ preventScroll: true });
    }
  }

  // The state of the card, on the card and on its cells that fold
  keepState(event: CustomEvent) {
    const { attributeName } = event.detail;
    if (attributeName !== 'data-open' && attributeName !== 'aria-expanded')
      return;

    const target = event.target as HTMLElement;
    if (target === this.element || this.toggleTargets.includes(target))
      event.preventDefault();
  }

  // The map, while its address stays
  keepMap(event: CustomEvent) {
    const map = event.target as HTMLElement;
    if (map.localName !== 'turbo-frame' || !this.hasMapTarget) return;
    if (map !== this.mapTarget) return;

    const { newElement } = event.detail;
    if (
      newElement instanceof Element &&
      this.address(newElement) === this.address(map)
    )
      event.preventDefault();
  }

  // The box takes its new height at once. The animation runs from the old
  // height to it, also from the middle of an animation before. A box that
  // fills the window takes its height from the flex layout, so the animation
  // leaves the layout for its duration.
  private animateBox(from: number, open: boolean) {
    this.resize?.cancel();
    if (isReducedMotion()) return;

    const to = this.boxTarget.getBoundingClientRect().height;
    const map = open && this.hasMapTarget ? this.mapTarget : null;
    if (map) this.holdMap(map);

    this.resize = this.boxTarget.animate(
      [
        { height: `${from}px`, flex: '0 0 auto' },
        { height: `${to}px`, flex: '0 0 auto' },
      ],
      { duration: 250, easing: EASE_QUICK },
    );
    if (map)
      this.resize.finished.then(
        () => this.showMap(map, true),
        () => this.showMap(map, false),
      );
  }

  // While the box grows, the map keeps its final size and stays hidden, so
  // MapLibre does not draw it again at each step
  private holdMap(map: HTMLElement) {
    const { height } = map.getBoundingClientRect();
    Object.assign(map.style, {
      flex: 'none',
      height: `${height}px`,
      opacity: '0',
    });
  }

  // The map returns to the layout at the same size, and fades in after a
  // finished animation
  private showMap(map: HTMLElement, fade: boolean) {
    Object.assign(map.style, { flex: '', height: '', opacity: '' });
    if (fade)
      map.animate([{ opacity: 0 }, { opacity: 1 }], {
        duration: 150,
        easing: 'ease-out',
      });
  }

  private address(frame: Element): string {
    return new URL(frame.getAttribute('src') ?? '', window.location.href).href;
  }
}
