import { Controller } from '@hotwired/stimulus';
import { enter, leave } from 'el-transition';

export default class extends Controller<HTMLElement> {
  static readonly targets = ['dialog', 'inner'];

  declare readonly hasDialogTarget: boolean;
  declare readonly dialogTarget: HTMLElement;
  declare readonly dialogTargets: HTMLElement[];

  declare readonly hasInnerTarget: boolean;
  declare readonly innerTarget: HTMLElement;
  declare readonly innerTargets: HTMLElement[];

  connect() {
    this.element.dataset.action =
      'turbo:submit-end->turbo-modal--component#submitEnd ' +
      'turbo:before-render@document->turbo-modal--component#closeBeforeRender ' +
      'keyup@window->turbo-modal--component#closeWithKeyboard ' +
      'click@window->turbo-modal--component#closeBackground ';

    enter(this.dialogTarget);
  }

  // Close dialog with animation
  closeDialog(event?: CustomEvent) {
    // Remove src reference from parent frame element (just to clean up)
    this.element.parentElement?.removeAttribute('src');

    leave(this.dialogTarget).then(() => {
      this.dialogTarget.remove();

      if (event?.detail.resume) event.detail.resume();
    });
  }

  // Ensure to close dialog (with animation) BEFORE Turbo renders new page
  closeBeforeRender(event: CustomEvent) {
    event.preventDefault();
    this.closeDialog(event);
  }

  // Close dialog on successful form submission
  submitEnd(event: CustomEvent) {
    if (event.detail.success) this.closeDialog();
  }

  // Close dialog when clicking ESC
  closeWithKeyboard(event: CustomEvent) {
    if (event instanceof KeyboardEvent && event.code == 'Escape')
      this.closeDialog();
  }

  // Close dialog when clicking outside
  closeBackground(event: Event) {
    if (
      event.target instanceof HTMLElement &&
      this.innerTarget.contains(event.target)
    )
      return;

    this.closeDialog();
  }
}
