import { Controller } from '@hotwired/stimulus';
import { isReducedMotion } from '@/utils/device';

type BeforeFetchRequestEvent = CustomEvent<{ resume: () => void }>;
type BeforeRenderEvent = CustomEvent<{ newBody: HTMLElement }>;

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
// Any other visit, the back gesture of the browser included, slides when Turbo
// renders. Its direction comes from the hierarchy: the next page is a child
// when its parent is this page, and it is the parent when this page names it
// as such.
export default class extends Controller<HTMLElement> {
  #slide?: Promise<void>;
  #skeleton?: HTMLElement;

  slide(event: Event) {
    const link = (event.target as HTMLElement).closest<HTMLAnchorElement>(
      'a[data-nav-title]',
    );
    if (!link || this.#slide || !this.#canSlide()) return;

    const direction =
      link.pathname === this.element.dataset.parent ? 'pop' : 'push';
    document.documentElement.dataset.navDirection = direction;
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
    const current = this.element.dataset;
    const next = newBody.querySelector<HTMLElement>('.nav-title-bar')?.dataset;

    let direction = 'none';
    if (this.#skeleton) this.#skeleton.remove();
    else if (next?.parent === current.path) direction = 'push';
    else if (current.parent && current.parent === next?.path) direction = 'pop';

    document.documentElement.dataset.navDirection = direction;
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
  #showSkeleton(title: string, direction: string) {
    const bar = this.element.cloneNode(true) as HTMLElement;
    bar.removeAttribute('data-controller');
    bar.removeAttribute('data-action');
    bar.classList.add('nav-skeleton-title');
    bar.querySelector('h1')!.textContent = title;
    bar
      .querySelector('.nav-back')
      ?.classList.toggle('invisible', direction === 'pop');

    const page = document.createElement('div');
    page.className = 'nav-skeleton-page';

    this.#skeleton = document.createElement('div');
    this.#skeleton.className = 'nav-skeleton';
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
