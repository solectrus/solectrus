import { Controller } from '@hotwired/stimulus';
import * as Turbo from '@hotwired/turbo';
import { isReducedMotion } from '@/utils/device';
import { EASE_GLIDE } from '@/utils/motion';
import { hasUnsavedChanges } from '@/utils/unsavedChanges';
import type ConfirmDialogController from '../confirm_dialog/component_controller';

// The frame of the pages of a sheet (Ui::SheetPage::Component). A page one
// level down slides in from the right, over the page it leaves, and the way
// back slides it out to the right again, as a navigation stack of iOS does.
// Pages of the same level change in place. Each page starts at its top.
//
// The slide is the answer to the tap, so it starts at once, while the page
// loads. A link with data-nav-title leads one level down: the slide shows a
// skeleton of the next page, its head with that title. A link to the page
// that the last slide down left goes back up: the slide uncovers a copy of
// that page. The page renders when the slide has ended, because a render
// would cut the slide short, and the skeleton or the copy then fades out
// over it. Any other change of the page slides when it renders.
//
// A link stays in the sheet, also a link in a frame inside the page that
// leads to the whole page, like a row of a list that loaded later. A link
// that leaves a form with unsaved changes asks first, in
// Ui::ConfirmDialog::Component, its outlet.

const DURATION = 350;
// The page below moves this far while the page above covers it
const PARALLAX = '-30%';
// The skeleton or the copy fades out this fast over the page that rendered
const FADE = 150;

type FrameRender = (current: Element, next: Element) => Promise<void> | void;
type FrameRenderEvent = CustomEvent<{
  newFrame: Element;
  render: FrameRender;
  resume: () => void;
}>;

// A slide that started at the tap: the layers over the area that scrolls
// until the page renders, and the end of the slide
interface Slide {
  layers: HTMLElement[];
  finished: Promise<void>;
}

export default class extends Controller<HTMLElement> {
  static readonly outlets = ['ui--confirm-dialog--component'];

  declare readonly hasUiConfirmDialogComponentOutlet: boolean;
  declare readonly uiConfirmDialogComponentOutlet: ConfirmDialogController;

  // The link of the last tap that loads into this frame, and the path of the
  // page it leaves
  #link?: { element: HTMLAnchorElement; from: string };
  // The page that the last slide down left, for the way back
  #above?: { path: string; page: HTMLElement };
  #slide?: Slide;

  // Stimulus Action (turbo:before-fetch-request). A tap on a link slides
  // at once, while the page loads.
  start(event: Event): void {
    const link = this.#link;
    this.#link = undefined;
    const area = this.#area();
    if (event.target !== this.element || !link || !area) return;

    const { url } = (event as CustomEvent<{ url: URL }>).detail;
    if (path(link.element, true) !== path(url, true) || isReducedMotion())
      return;

    this.#finish();
    if (this.#above?.path === path(link.element)) this.#pop(area);
    else if (link.element.dataset.navTitle && depth(this.element) === 0)
      this.#push(area, link.element.dataset.navTitle, link.from);
  }

  // Stimulus Action (turbo:before-frame-render). The new page starts at its
  // top. A slide that started at the tap holds the render until it has
  // ended, else a page of another level slides now.
  render(event: Event): void {
    const area = this.#area();
    if (event.target !== this.element || !area) return;

    const { detail } = event as FrameRenderEvent;
    const render = detail.render;
    const slide = this.#slide;
    this.#slide = undefined;

    if (slide) {
      event.preventDefault();
      detail.render = async (current, next) => {
        await render(current, next);
        area.scrollTop = 0;
        void fadeOut(slide.layers).then(() => release(area));
      };
      void slide.finished.then(detail.resume);
      return;
    }

    const from = depth(this.element);
    const to = depth(detail.newFrame);
    const slides = from !== to && !isReducedMotion();

    detail.render = async (current, next) => {
      const ghost = slides ? snapshot(area) : null;
      await render(current, next);
      area.scrollTop = 0;
      if (!ghost) return;

      const kind = to > from ? 'push' : 'pop';
      isolate(area);
      void move(area, ghost, kind).then(() => {
        ghost.remove();
        release(area);
        for (const name of ['position', 'background', 'z-index', 'box-shadow'])
          area.style.removeProperty(name);
      });
    };
  }

  // Stimulus Action (turbo:fetch-request-error, turbo:frame-missing). The
  // page did not come, so the page of the tap shows again.
  abort(event: Event): void {
    if (event.target === this.element) this.#finish();
  }

  // Stimulus Action (click, in the capture phase, before Turbo). A link that
  // loads into this frame leaves the page and its form.
  guard(event: MouseEvent): void {
    const link = (event.target as Element | null)?.closest?.('a[href]');
    if (!(link instanceof HTMLAnchorElement)) return;
    if (event.metaKey || event.ctrlKey || event.shiftKey || event.altKey)
      return;

    const frame = link.dataset.turboFrame;
    if (frame && frame !== this.element.id) return;

    this.#link = { element: link, from: this.#path() };
    const toTop =
      link.closest('turbo-frame')?.getAttribute('target') === '_top';
    const asks =
      hasUnsavedChanges(this.element) && this.hasUiConfirmDialogComponentOutlet;
    if (!toTop && !asks) return;

    event.preventDefault();
    event.stopImmediatePropagation();
    const visit = () => Turbo.visit(link.href, { frame: this.element.id });
    if (!asks) return visit();

    void this.uiConfirmDialogComponentOutlet
      .confirmDiscard()
      .then((discard) => discard && visit());
  }

  // The skeleton of the next page slides in over this one. This page stays
  // for the way back.
  #push(area: HTMLElement, title: string, from: string) {
    const page = snapshot(area);
    const next = skeleton(area, this.element, title);
    this.#above = { path: from, page };
    const finished = move(next, page, 'push').then(() => page.remove());
    this.#hold(area, [next], finished);
  }

  // This page slides out and uncovers the copy of the page above, at its top
  #pop(area: HTMLElement) {
    const next = cover(area, this.#above!.page);
    this.#above = undefined;
    next.scrollTop = 0;
    const page = snapshot(area);
    const finished = move(next, page, 'pop').then(() => page.remove());
    this.#hold(area, [next, page], finished);
  }

  // The area stays below the layers until the page renders
  #hold(area: HTMLElement, layers: HTMLElement[], finished: Promise<void>) {
    isolate(area);
    this.#slide = { layers, finished };
  }

  #finish() {
    if (!this.#slide) return;

    for (const layer of this.#slide.layers) layer.remove();
    this.#above?.page.remove();
    this.#slide = undefined;
    const area = this.#area();
    if (area) release(area);
  }

  #area() {
    return this.element.closest<HTMLElement>('.bottom-sheet-content');
  }

  // The path of this page. The first page loaded into the modal frame.
  #path() {
    const src = this.element.closest('turbo-frame[src]')?.getAttribute('src');
    return src ? path(new URL(src, location.href)) : '';
  }
}

// The level of a page: a page with a way back lies one level down
function depth(frame: Element): number {
  return Number(
    frame.querySelector<HTMLElement>('[data-sheet-depth]')?.dataset
      .sheetDepth ?? 0,
  );
}

// The path of an address, with its query for a comparison of the same request
function path(url: URL | HTMLAnchorElement, query = false): string {
  return query ? url.pathname + url.search : url.pathname;
}

// A still copy of the page that leaves, over the area that scrolls, at its
// scroll position
function snapshot(area: HTMLElement): HTMLElement {
  const ghost = cover(area, area.cloneNode(true) as HTMLElement);
  ghost.scrollTop = area.scrollTop;
  return ghost;
}

// The next page before it loads: the head of this page with the title of the
// next one, without the subtitle, the way back and the actions of this page
function skeleton(
  area: HTMLElement,
  frame: HTMLElement,
  title: string,
): HTMLElement {
  const box = document.createElement('div');
  box.className = frame.className;
  const head = frame.querySelector('header[data-sheet-depth]');
  if (head) {
    const copy = head.cloneNode(true) as HTMLElement;
    const [back, , actions] = copy.children;
    if (back instanceof HTMLElement) back.style.visibility = 'hidden';
    actions?.replaceChildren();
    copy.querySelector('p')?.remove();
    const heading = copy.querySelector('h2');
    if (heading) heading.textContent = title;
    box.append(copy);
  }

  const page = area.cloneNode(false) as HTMLElement;
  page.append(box);
  return cover(area, page);
}

// Lays a page over the area that scrolls. It takes no input, starts no
// controller and loads no frame.
function cover(area: HTMLElement, page: HTMLElement): HTMLElement {
  const names = ['id', 'data-controller', 'data-action', 'src'];
  const selector = names.map((name) => `[${name}]`).join(',');
  for (const element of [page, ...page.querySelectorAll(selector)]) {
    for (const name of names) element.removeAttribute(name);
  }
  page.inert = true;
  page.setAttribute('aria-hidden', 'true');
  Object.assign(page.style, {
    position: 'absolute',
    top: `${area.offsetTop}px`,
    left: `${area.offsetLeft}px`,
    width: `${area.offsetWidth}px`,
    height: `${area.clientHeight}px`,
    overflow: 'hidden',
    pointerEvents: 'none',
  });
  area.after(page);
  return page;
}

// A push slides the next page in over the page it leaves, a pop slides the
// page it leaves out and uncovers the next one
function move(
  next: HTMLElement,
  page: HTMLElement,
  kind: 'push' | 'pop',
): Promise<void> {
  const options = { duration: DURATION, easing: EASE_GLIDE };
  // Both pages cover what lies below them, in the color of the sheet
  const background = getComputedStyle(
    next.closest('.bottom-sheet-panel') ?? next,
  ).backgroundColor;
  for (const element of [next, page]) {
    if (getComputedStyle(element).position === 'static')
      element.style.position = 'relative';
    element.style.background = background;
  }
  const above = kind === 'push' ? next : page;
  above.style.zIndex = '1';
  above.style.boxShadow = '-8px 0 24px rgb(0 0 0 / 0.15)';

  const animations =
    kind === 'push'
      ? [
          next.animate(
            [{ transform: 'translateX(100%)' }, { transform: 'none' }],
            options,
          ),
          page.animate(
            [{ transform: 'none' }, { transform: `translateX(${PARALLAX})` }],
            options,
          ),
        ]
      : [
          page.animate(
            [{ transform: 'none' }, { transform: 'translateX(100%)' }],
            options,
          ),
          next.animate(
            [{ transform: `translateX(${PARALLAX})` }, { transform: 'none' }],
            options,
          ),
        ];

  return Promise.allSettled(animations.map((it) => it.finished)).then(
    () => undefined,
  );
}

// The head of a page sticks above the rest of it. While a slide lasts, the
// area keeps it among its own content, so the head of the page that leaves
// does not show above the layers. The area takes no tap meanwhile.
function isolate(area: HTMLElement) {
  area.inert = true;
  area.style.isolation = 'isolate';
}

function release(area: HTMLElement) {
  area.inert = false;
  area.style.removeProperty('isolation');
}

// The page has rendered below the layers, which fade out over it
function fadeOut(layers: HTMLElement[]): Promise<void> {
  const fades = layers.map((layer) =>
    layer
      .animate([{ opacity: 1 }, { opacity: 0 }], {
        duration: FADE,
        fill: 'forwards',
      })
      .finished.finally(() => layer.remove()),
  );
  return Promise.allSettled(fades).then(() => undefined);
}
