import { Controller } from '@hotwired/stimulus';
import * as Turbo from '@hotwired/turbo';
import { isReducedMotion } from '@/utils/device';
import { hasUnsavedChanges } from '@/utils/unsavedChanges';
import type ConfirmDialogController from '../confirm_dialog/component_controller';

// The frame of the pages of a sheet (Ui::SheetPage::Component). A page one
// level down slides in from the right, over the page it leaves, and the way
// back slides it out to the right again, as a navigation stack of iOS does.
// Pages of the same level change in place. Each page starts at its top.
//
// A link stays in the sheet, also a link in a frame inside the page that
// leads to the whole page, like a row of a list that loaded later. A link
// that leaves a form with unsaved changes asks first, in
// Ui::ConfirmDialog::Component, its outlet.

const DURATION = 350;
const EASING = 'cubic-bezier(0.32, 0.72, 0, 1)';
// The page below moves this far while the page above covers it
const PARALLAX = '-30%';

type FrameRender = (current: Element, next: Element) => Promise<void> | void;

export default class extends Controller<HTMLElement> {
  static readonly outlets = ['ui--confirm-dialog--component'];

  declare readonly hasUiConfirmDialogComponentOutlet: boolean;
  declare readonly uiConfirmDialogComponentOutlet: ConfirmDialogController;

  // Stimulus Action (turbo:before-frame-render). The new page starts at its
  // top, and a page of another level slides.
  render(event: Event): void {
    const area = this.element.closest<HTMLElement>('.bottom-sheet-content');
    if (event.target !== this.element || !area) return;

    const detail = (
      event as CustomEvent<{ newFrame: Element; render: FrameRender }>
    ).detail;
    const from = depth(this.element);
    const to = depth(detail.newFrame);
    const slides = from !== to && !isReducedMotion();
    const render = detail.render;

    detail.render = async (current, next) => {
      const ghost = slides ? snapshot(area) : null;
      await render(current, next);
      area.scrollTop = 0;
      if (ghost) move(area, ghost, to > from ? 'push' : 'pop');
    };
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
}

// The level of a page: a page with a way back lies one level down
function depth(frame: Element): number {
  return Number(
    frame.querySelector<HTMLElement>('[data-sheet-depth]')?.dataset
      .sheetDepth ?? 0,
  );
}

// A still copy of the page that leaves, over the area that scrolls, at its
// scroll position. It takes no input, starts no controller and loads no frame.
function snapshot(area: HTMLElement): HTMLElement {
  const ghost = area.cloneNode(true) as HTMLElement;
  const names = ['id', 'data-controller', 'data-action', 'src'];
  const selector = names.map((name) => `[${name}]`).join(',');
  for (const element of [ghost, ...ghost.querySelectorAll(selector)]) {
    for (const name of names) element.removeAttribute(name);
  }
  ghost.inert = true;
  ghost.setAttribute('aria-hidden', 'true');
  Object.assign(ghost.style, {
    position: 'absolute',
    top: `${area.offsetTop}px`,
    left: `${area.offsetLeft}px`,
    width: `${area.offsetWidth}px`,
    height: `${area.clientHeight}px`,
    overflow: 'hidden',
    pointerEvents: 'none',
  });
  area.after(ghost);
  ghost.scrollTop = area.scrollTop;
  return ghost;
}

// A push slides the new page in over the old one, a pop slides the old page
// out and uncovers the new one
function move(area: HTMLElement, ghost: HTMLElement, kind: 'push' | 'pop') {
  const options = { duration: DURATION, easing: EASING };
  // Both pages cover what lies below them, in the color of the sheet
  const background = getComputedStyle(
    area.closest('.bottom-sheet-panel') ?? area,
  ).backgroundColor;
  area.style.position = 'relative';
  area.style.background = background;
  ghost.style.background = background;
  const above = kind === 'push' ? area : ghost;
  above.style.zIndex = '1';
  above.style.boxShadow = '-8px 0 24px rgb(0 0 0 / 0.15)';

  const animations =
    kind === 'push'
      ? [
          area.animate(
            [{ transform: 'translateX(100%)' }, { transform: 'none' }],
            options,
          ),
          ghost.animate(
            [{ transform: 'none' }, { transform: `translateX(${PARALLAX})` }],
            options,
          ),
        ]
      : [
          ghost.animate(
            [{ transform: 'none' }, { transform: 'translateX(100%)' }],
            options,
          ),
          area.animate(
            [{ transform: `translateX(${PARALLAX})` }, { transform: 'none' }],
            options,
          ),
        ];

  void Promise.allSettled(animations.map((it) => it.finished)).then(() => {
    ghost.remove();
    for (const name of ['position', 'background', 'z-index', 'box-shadow'])
      area.style.removeProperty(name);
  });
}
