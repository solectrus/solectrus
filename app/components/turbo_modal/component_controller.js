import { Controller } from '@hotwired/stimulus';
import { enter, leave } from 'el-transition';

export default class extends Controller {
  static targets = ['dialog', 'inner'];

  connect() {
    this.element.dataset.action =
      'turbo:submit-end->turbo-modal--component#submitEnd \
       turbo:before-render@document->turbo-modal--component#closeBeforeRender \
       keyup@window->turbo-modal--component#closeWithKeyboard \
       click@window->turbo-modal--component#closeBackground';

    enter(this.dialogTarget);
  }

  // Close dialog with animation
  closeDialog(event) {
    // Remove src reference from parent frame element (just to clean up)
    this.element.parentElement.removeAttribute('src');

    leave(this.dialogTarget).then(() => {
      this.dialogTarget.remove();

      if (event?.detail.resume) event.detail.resume();
    });
  }

  // Ensure to close dialog (with animation) BEFORE Turbo renders new page
  closeBeforeRender(event) {
    event.preventDefault();
    this.closeDialog(event);
  }

  // Close dialog on successful form submission
  submitEnd(event) {
    if (event.detail.success) this.closeDialog();
  }

  // Close dialog when clicking ESC
  closeWithKeyboard(event) {
    if (event.code == 'Escape') this.closeDialog();
  }

  // Close dialog when clicking outside
  closeBackground(event) {
    if (event && this.innerTarget.contains(event.target)) return;

    this.closeDialog();
  }
}
