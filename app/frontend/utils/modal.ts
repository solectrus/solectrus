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
