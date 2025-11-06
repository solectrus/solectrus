import { Controller } from '@hotwired/stimulus';
import { enter, leave } from 'el-transition';

export default class extends Controller<HTMLElement> {
  static readonly targets = ['dialog', 'inner', 'backdrop'];

  declare readonly dialogTarget: HTMLDialogElement;
  declare readonly innerTarget: HTMLElement;
  declare readonly backdropTarget: HTMLElement;

  connect() {
    // Open dialog as modal with native API
    this.dialogTarget.showModal();

    // Prevent auto-focus on first focusable element (e.g., summary elements)
    // Focus the dialog itself instead
    this.dialogTarget.focus();

    // Animate in backdrop and content
    Promise.all([enter(this.backdropTarget), enter(this.innerTarget)]);
  }

  // Close dialog with animation
  closeDialog(event?: CustomEvent) {
    // Animate out backdrop and content
    Promise.all([leave(this.backdropTarget), leave(this.innerTarget)]).then(
      () => {
        if (event?.detail?.resume) event.detail.resume();

        // Close the native dialog
        this.dialogTarget.close();

        // Remove the element from DOM
        this.element.remove();
      },
    );
  }

  // Handle cancel event (triggered by ESC key, before dialog closes)
  handleCancel(event: Event) {
    event.preventDefault();
    this.closeDialog();
  }

  // Ensure to close dialog (with animation) BEFORE Turbo renders new page
  closeBeforeRender(event: Event) {
    event.preventDefault();
    this.closeDialog(event as CustomEvent);
  }

  // Close dialog on successful form submission
  submitEnd(event: CustomEvent) {
    if (event.detail.success) this.closeDialog();
  }

  // Close dialog when clicking outside
  closeBackground(event: Event) {
    if (!(event.target instanceof HTMLElement)) return;

    // Close if clicking on backdrop or dialog itself (not on content inside)
    if (
      event.target !== this.backdropTarget &&
      event.target !== this.dialogTarget
    )
      return;

    this.closeDialog();
  }
}
