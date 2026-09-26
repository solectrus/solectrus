import { Controller } from '@hotwired/stimulus';
import { BottomSheet } from '@/utils/bottomSheet';

// Shows the page of a modal frame request in a BottomSheet, and removes it from
// the frame once it is closed
export default class extends Controller<HTMLElement> {
  static readonly targets = ['dialog'];

  declare readonly dialogTarget: HTMLDialogElement;

  private sheet: BottomSheet | null = null;

  connect(): void {
    this.sheet = new BottomSheet(this.dialogTarget, {
      onClosed: () => this.element.remove(),
      // An open <details> inside takes Escape first
      canCancel: () => !this.dialogTarget.querySelector('details[open]'),
    });

    // modal-launcher shows this backdrop at the click, while the frame loads.
    // The sheet dims the page itself. It takes over from the preloaded
    // backdrop without a fade, because both have the same color.
    this.sheet.open({ instant: backdrop()?.dataset.preloaded === 'true' });
    hideBackdrop();
  }

  disconnect(): void {
    hideBackdrop();
    this.sheet?.destroy();
    this.sheet = null;
  }

  // Stimulus Action: Close with animation, for a button inside the content
  closeDialog(): void {
    this.sheet?.close();
  }

  // Stimulus Action: Close on successful form submission
  // Called via data-action="turbo:submit-end->turbo-modal--component#submitEnd"
  submitEnd(event: CustomEvent): void {
    if (event.detail.success) this.closeDialog();
  }
}

function backdrop(): HTMLElement | null {
  return document.getElementById('modal-backdrop');
}

// 'hidden' too, not just a transparent backdrop. Safari reads the color of
// its toolbar from a fixed element that covers the viewport and ignores the
// opacity, so a backdrop left behind here would tint the toolbar gray.
function hideBackdrop(): void {
  const element = backdrop();
  if (!element) return;

  element.classList.add('pointer-events-none', 'opacity-0', 'hidden');
  element.classList.remove('opacity-100');
  delete element.dataset.preloaded;
}
