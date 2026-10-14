import * as Turbo from '@hotwired/turbo';
import { enter } from '@/utils/transition';

const FRAME_ID = 'modal';

function backdrop(): HTMLElement | null {
  return document.getElementById('modal-backdrop');
}

// Shows the backdrop of the modal at once, while its frame loads. The sheet
// takes it over without a fade (turbo_modal/component_controller.ts).
export function preloadModalBackdrop(): void {
  const element = backdrop();
  if (!element) return;

  element.dataset.preloaded = 'true';
  element.classList.remove('pointer-events-none');
  enter(element);
}

export function isModalBackdropPreloaded(): boolean {
  return backdrop()?.dataset.preloaded === 'true';
}

// 'hidden' too, not just a transparent backdrop. Safari reads the color of
// its toolbar from a fixed element that covers the viewport and ignores the
// opacity, so a backdrop left behind here would tint the toolbar gray.
export function hideModalBackdrop(): void {
  const element = backdrop();
  if (!element) return;

  element.classList.add('pointer-events-none', 'opacity-0', 'hidden');
  element.classList.remove('opacity-100');
  delete element.dataset.preloaded;
}

// Loads a page into the modal, as a link with data-turbo-frame="modal" does
export function openModal(url: string): void {
  preloadModalBackdrop();
  Turbo.visit(url, { frame: FRAME_ID });
}

// Turbo hands a hover prefetch to the next request for its URL, and the
// timeframe select loads the URL of the page itself. On a phone, the tap on a
// pagination arrow prefetches the next page only after the visit, so the
// modal would get the whole page and stay empty.
document.addEventListener('turbo:before-fetch-request', (event) => {
  const { target, detail } = event as CustomEvent<{ fetchRequest?: unknown }>;
  if (target instanceof HTMLElement && target.id === FRAME_ID)
    delete detail.fetchRequest;
});

// So a link into the modal needs no prefetch at all. A prefetch would also
// run the action twice: the form of a place asks Nominatim in the prefetch,
// and the second request no longer sends the new locality to the list.
document.addEventListener('turbo:before-prefetch', (event) => {
  const { target } = event;
  if (target instanceof HTMLElement && target.dataset.turboFrame === FRAME_ID)
    event.preventDefault();
});

// Without a network, no sheet comes to take the backdrop over, and the page
// stays dim and blocked. The frame also loses its src: a retry of stuck
// frames (utils/setupStimulus.ts) would open the sheet much later, when the
// user no longer expects it.
document.addEventListener('turbo:fetch-request-error', (event) => {
  const frame = event.target;
  if (!(frame instanceof HTMLElement) || frame.id !== FRAME_ID) return;

  frame.removeAttribute('src');
  hideModalBackdrop();
});
