import { Controller } from '@hotwired/stimulus';
import { enter, leave } from 'el-transition';

export default class extends Controller<HTMLElement> {
  static readonly targets = ['dialog', 'inner'];

  declare readonly dialogTarget: HTMLDialogElement;
  declare readonly innerTarget: HTMLElement;

  private backdrop: HTMLElement | null = null;
  private animationFrameId: number | null = null;

  connect(): void {
    // Get the shared backdrop from the layout
    this.backdrop = document.getElementById('modal-backdrop');
    if (!this.backdrop) return;

    // Add click handler to backdrop
    this.backdrop.addEventListener('click', this.handleBackdropClick);

    // Check if backdrop was preloaded by modal-launcher
    const backdropPreloaded = this.backdrop.dataset.preloaded === 'true';

    // Wait for the browser to render the initial position before showing the dialog
    // This prevents the "jumping" effect on large modals
    this.animationFrameId = requestAnimationFrame(() => {
      // Guard: Check if controller is still connected and backdrop exists
      if (!this.backdrop) return;

      // Open dialog as modal with native API
      this.dialogTarget.showModal();

      // Prevent auto-focus on first focusable element (e.g., summary elements)
      // Focus the dialog itself instead
      this.dialogTarget.focus();

      if (backdropPreloaded) {
        // Remove the preload marker
        delete this.backdrop.dataset.preloaded;

        // Backdrop is already visible from modal-launcher, just animate in the content
        enter(this.innerTarget);
        return;
      }

      // Animate in both backdrop and content
      this.backdrop.classList.remove('pointer-events-none');
      Promise.all([enter(this.backdrop), enter(this.innerTarget)]);
    });
  }

  disconnect(): void {
    // Cancel pending animation frame to prevent race condition
    if (this.animationFrameId !== null) {
      cancelAnimationFrame(this.animationFrameId);
      this.animationFrameId = null;
    }

    // Clean up: hide and disable the backdrop
    if (!this.backdrop) return;

    this.backdrop.removeEventListener('click', this.handleBackdropClick);
    this.backdrop.classList.add('pointer-events-none', 'opacity-0');
    this.backdrop.classList.remove('opacity-100');
    delete this.backdrop.dataset.preloaded; // Clean up any leftover marker
  }

  // Public method: Close dialog with animation
  // Can be called programmatically or from other controllers
  closeDialog(event?: CustomEvent): void {
    if (!this.backdrop) return;

    const backdrop = this.backdrop; // Capture for use in callback

    // Animate out backdrop and content
    Promise.all([leave(backdrop), leave(this.innerTarget)]).then(() => {
      if (event?.detail?.resume) event.detail.resume();

      // Close the native dialog
      this.dialogTarget.close();

      // Disable backdrop
      backdrop.classList.add('pointer-events-none');

      // Remove the element from DOM
      this.element.remove();
    });
  }

  // Private event handler for backdrop clicks
  private readonly handleBackdropClick = (): void => {
    this.closeDialog();
  };

  // Stimulus Action: Handle cancel event (triggered by ESC key)
  // Called via data-action="cancel->turbo-modal--component#handleCancel"
  handleCancel(event: Event): void {
    // Check if there are any open child elements that should handle ESC first
    const hasOpenDetails = this.innerTarget.querySelector('details[open]');

    // If a child component is open, don't close the modal - let it handle ESC first
    if (hasOpenDetails) {
      event.preventDefault();
      return;
    }

    // No open child components, close the modal with animation
    event.preventDefault();
    this.closeDialog();
  }

  // Stimulus Action: Close dialog on successful form submission
  // Called via data-action="turbo:submit-end->turbo-modal--component#submitEnd"
  submitEnd(event: CustomEvent): void {
    if (event.detail.success) this.closeDialog();
  }

  // Stimulus Action: Close dialog when clicking on the dialog background
  // Called via data-action="click->turbo-modal--component#closeBackground"
  closeBackground(event: Event): void {
    if (!(event.target instanceof HTMLElement)) return;

    // Close only if clicking on the dialog itself (not on content inside)
    if (event.target !== this.dialogTarget) return;

    this.closeDialog();
  }
}
