import { Controller } from '@hotwired/stimulus';
import { isReducedMotion } from '@/utils/device';
import { isEntryBefore } from '@/utils/historyTrail';

type BeforeFetchRequestEvent = CustomEvent<{ resume: () => void }>;
type BeforeRenderEvent = CustomEvent<{ newBody: HTMLElement }>;
type TurboClickEvent = CustomEvent<{ originalEvent: Event }>;

// Slides between the pages of a drill-down hierarchy (see component.css).
//
// A tap on a link with data-nav-title slides at once to a skeleton of the next
// page: that title over an empty page. The link leads up when it points to the
// parent, else down. The request waits until the slide has ended, because the
// render of the response would cut the slide short. The response then fades in
// over the skeleton. These links opt out of the hover prefetch: a tap is faster
// than its delay, and after the slide the finger rests over a row, which would
// be prefetched for nothing.
//
// The back button goes back in the history when the entry before is the
// parent, as the back button of iOS does. It slides first, and the browser
// goes back when the slide has ended. So the page leaves the history, and the
// back button of Android or a back gesture later does not lead to it again.
// Without such an entry, like after a reload, the button visits the parent.
//
// Any other visit, the back button of the browser included, slides when Turbo
// renders. Its direction comes from the hierarchy: the next page is a child
// when its parent is this page, and it is the parent when this page names it
// as such.
//
// A back gesture can bring its own animation, like the predictive back of
// Chrome on Android. A browser that animates reports hasUAVisualTransition,
// and the page then changes at once: a second slide would repeat the one the
// finger just made. The back button of Android has no such animation and
// slides as before.
let browserAnimated = false;

addEventListener('popstate', (event) => {
  browserAnimated =
    (event as PopStateEvent & { hasUAVisualTransition?: boolean })
      .hasUAVisualTransition === true;
});
// A popstate that Turbo does not follow, like a change of the hash, must not
// keep the flag for the next visit
addEventListener('turbo:load', () => (browserAnimated = false));
addEventListener('turbo:visit', (event) => {
  const { action } = (event as CustomEvent<{ action: string }>).detail;
  if (action !== 'restore') browserAnimated = false;
});

export default class extends Controller<HTMLElement> {
  #slide?: Promise<void>;
  #skeleton?: HTMLElement;
  #leaving = false;

  slide(event: TurboClickEvent) {
    const target = event.target as HTMLElement;
    const back = target.closest<HTMLAnchorElement>('a.ui-title-bar-back');
    if (back && this.element.contains(back) && isEntryBefore(back)) {
      // Neither Turbo nor the browser follows the link
      event.preventDefault();
      event.detail.originalEvent.preventDefault();
      // The entry before stays the parent until the browser has gone back,
      // so a second tap would go back a second step
      if (!this.#leaving) void this.#goBack(back);
      return;
    }

    const link = target.closest<HTMLAnchorElement>('a[data-nav-title]');
    if (!link || this.#slide || !this.#canSlide()) return;

    this.#startSlide(link);
  }

  // The render of the parent would cut the slide short, so the browser goes
  // back only when the slide has ended
  async #goBack(link: HTMLAnchorElement) {
    this.#leaving = true;
    if (link.dataset.navTitle && !this.#slide && this.#canSlide()) {
      this.#startSlide(link);
      await this.#slide;
    }
    history.back();
  }

  #startSlide(link: HTMLAnchorElement) {
    const direction =
      link.pathname === this.element.dataset.parent ? 'pop' : 'push';
    const { dataset } = document.documentElement;
    dataset.navDirection = direction;
    // The slide is the answer to the tap, so the content does not go away for
    // the visit (see application.css). The old page goes into the slide as it is.
    dataset.navSliding = '';
    this.#slide = document.startViewTransition(() =>
      this.#showSkeleton(link.dataset.navTitle ?? '', direction),
    ).finished;
  }

  async hold(event: BeforeFetchRequestEvent) {
    if (!this.#slide) return;

    event.preventDefault();
    await this.#slide;
    event.detail.resume();
  }

  prepare({ detail: { newBody } }: BeforeRenderEvent) {
    delete document.documentElement.dataset.navSliding;
    const current = this.element.dataset;
    const next = newBody.querySelector<HTMLElement>('.ui-title-bar')?.dataset;

    // A page beside this one, with the same parent, like the other kind of a
    // list or its next timeframe, takes the place of this one at once
    let direction = 'none';
    if (this.#skeleton) this.#skeleton.remove();
    else if (browserAnimated) direction = 'across';
    else if (next?.parent === current.path) direction = 'push';
    else if (current.parent && current.parent === next?.path) direction = 'pop';
    else if (current.parent && current.parent === next?.parent)
      direction = 'across';

    // A morph keeps this controller, so the next slide starts afresh
    this.#skeleton = undefined;
    this.#slide = undefined;

    document.documentElement.dataset.navDirection = direction;
    this.#markRendering();
  }

  // The response is here, so nothing loads any more. Turbo would still show
  // the progress bar until the view transition has ended, over the new page,
  // and still mark the document as busy, which hides the content (see
  // application.css). The mark hides the bar and keeps the content in view
  // until turbo:load. Turbo starts to fade the bar out before turbo:load.
  #markRendering() {
    const { dataset } = document.documentElement;

    dataset.navRendering = '';
    document.addEventListener('turbo:load', () => delete dataset.navRendering, {
      once: true,
    });
  }

  #canSlide() {
    return (
      'startViewTransition' in document &&
      this.element.checkVisibility() &&
      !isReducedMotion()
    );
  }

  // Covers the title bar and the content area with a copy that shows the next
  // page. The layer sits beside <body>, not in it: Turbo neither caches it nor
  // replaces it, so it stays until prepare() removes it within the transition
  // to the response. Turbo removes data-turbo-temporary before that, from the
  // live page, and the old page would flash.
  //
  // The page of the skeleton covers the content area where it is, so this
  // page slides out to the side alone. The accessories of this page leave
  // the bar above it, and the gray of the content area fills the gap (see
  // component.css).
  #showSkeleton(title: string, direction: string) {
    const bar = this.element.cloneNode(true) as HTMLElement;
    bar.removeAttribute('data-controller');
    bar.removeAttribute('data-action');
    bar.classList.add('ui-title-bar-skeleton-title');
    bar.querySelector('h1')!.textContent = title;
    bar
      .querySelector('.ui-title-bar-back')
      ?.classList.toggle('invisible', direction === 'pop');
    // The action belongs to this page, the next one brings its own. The
    // backdrop stays with the header, a second one would repeat its name.
    bar.querySelector('.ui-title-bar-action')?.remove();
    bar.querySelector('.ui-title-bar-backdrop')?.remove();

    const page = document.createElement('div');
    page.className = 'ui-title-bar-skeleton-page';

    this.#skeleton = document.createElement('div');
    this.#skeleton.className = 'ui-title-bar-skeleton';
    this.#skeleton.inert = true;
    this.#skeleton.append(
      this.#cover(bar, this.element),
      this.#cover(page, document.querySelector('main')!),
    );
    document.documentElement.append(this.#skeleton);
  }

  #cover(element: HTMLElement, target: Element) {
    const { top, left, width, height } = target.getBoundingClientRect();
    Object.assign(element.style, {
      top: `${top}px`,
      left: `${left}px`,
      width: `${width}px`,
      height: `${height}px`,
    });
    return element;
  }
}
