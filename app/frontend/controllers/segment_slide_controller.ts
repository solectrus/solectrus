import { Controller } from '@hotwired/stimulus';
import { isReducedMotion } from '@/utils/device';

// Slides the marking of a segmented control from the selected segment to the
// tapped one, as the tab bar does (see optimistic_nav_controller).
//
// The segments are the elements that wear the marking: a label around a
// radio, the tile after a radio, or a button. A segment is selected when its
// radio is checked, or when it is a disabled button, like the current
// language. The classes of the template keep the look of the marking. This
// copies the look onto an element of its own, which moves below the
// segments, while the two segments show no marking themselves.
//
// A button that submits a form, like a change of the language, selects
// nothing here. The marking then stays on the tapped segment until the page
// that the form renders arrives. The request of the form waits until the
// marking has arrived, because the render of its answer would cut the slide
// short.
//
// The element needs `relative isolate`, so the marking lies inside it and
// below its content.
const DURATION = 250;
const EASING = 'cubic-bezier(0.32, 0.72, 0, 1)';
const SELECTED = ':has(> input:checked), input:checked ~ *, :disabled';

type BeforeFetchRequestEvent = CustomEvent<{ resume: () => void }>;

export default class extends Controller<HTMLElement> {
  static readonly targets = ['segment'];
  declare readonly segmentTargets: HTMLElement[];

  declare marking: HTMLElement | null;
  declare sliding: Promise<void> | null;

  disconnect() {
    this.marking?.remove();
  }

  // On the click, before the radio changes. A click on a label sends a second
  // click to its radio, which finds the change already done.
  move(event: Event) {
    if (isReducedMotion()) return;

    const to = this.segmentTargets.find((segment) =>
      segment.contains(event.target as Node),
    );
    const from = this.selected();
    if (!to || !from || to === from) return;

    const start = this.offset(from);
    // The request of a form starts before the next frame, so the slide is
    // known at once
    let done = () => {};
    const sliding = new Promise<void>((resolve) => (done = resolve));
    this.sliding = sliding;
    sliding.then(() => {
      if (this.sliding === sliding) this.sliding = null;
    });

    // The radio changes after the click, and a new theme with it. So the
    // marking takes its look from the next frame, before the browser paints.
    requestAnimationFrame(() => this.slide(start, from, to, done));
  }

  async hold(event: BeforeFetchRequestEvent) {
    if (!this.sliding) return;

    event.preventDefault();
    await this.sliding;
    event.detail.resume();
  }

  private slide(
    start: DOMRect,
    from: HTMLElement,
    to: HTMLElement,
    done: () => void,
  ) {
    this.marking?.remove();

    const arrived = to.matches(SELECTED);
    const style = getComputedStyle(arrived ? to : from);
    const target = this.offset(to);

    const marking = document.createElement('div');
    Object.assign(marking.style, {
      position: 'absolute',
      zIndex: '-1',
      pointerEvents: 'none',
      top: `${target.top}px`,
      height: `${target.height}px`,
      backgroundColor: style.backgroundColor,
      borderRadius: style.borderRadius,
      boxShadow: style.boxShadow,
    });
    this.element.prepend(marking);
    this.marking = marking;

    // Without a transition, so the marking of a segment neither fades out
    // at the start nor fades in at the end
    const segments = [from, to];
    segments.forEach((segment) =>
      Object.assign(segment.style, {
        transition: 'none',
        backgroundColor: 'transparent',
        boxShadow: 'none',
      }),
    );

    const end = () => {
      done();
      if (!arrived) return;

      segments.forEach((segment) => {
        segment.style.removeProperty('background-color');
        segment.style.removeProperty('box-shadow');
      });
      marking.remove();
      if (this.marking === marking) this.marking = null;
      requestAnimationFrame(() =>
        segments.forEach((segment) =>
          segment.style.removeProperty('transition'),
        ),
      );
    };

    marking
      .animate(
        [
          { left: `${start.left}px`, width: `${start.width}px` },
          { left: `${target.left}px`, width: `${target.width}px` },
        ],
        { duration: DURATION, easing: EASING, fill: 'forwards' },
      )
      .finished.then(end, end);
  }

  private selected() {
    return this.segmentTargets.find((segment) => segment.matches(SELECTED));
  }

  // The box of a segment within the element
  private offset(segment: HTMLElement) {
    const rect = segment.getBoundingClientRect();
    const box = this.element.getBoundingClientRect();
    return new DOMRect(
      rect.left - box.left,
      rect.top - box.top,
      rect.width,
      rect.height,
    );
  }
}
