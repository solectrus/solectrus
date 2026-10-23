import { Controller } from '@hotwired/stimulus';

// A map that fills the window over the page (see Car::MapOverlay::Component).
// It opens as a modal dialog. The close button and ESC empty its frame, so the
// page shows again.
export default class extends Controller<HTMLDialogElement> {
  connect() {
    this.element.showModal();
  }

  close() {
    const frame = this.element.closest('turbo-frame');
    if (!frame) return;

    // Without its src, the next click loads the frame again
    frame.removeAttribute('src');
    frame.replaceChildren();
  }

  // ESC empties the frame too, not only closes the dialog. The open
  // attribution of the map takes ESC first, and so no cancel comes.
  cancel(event: Event) {
    event.preventDefault();
    this.close();
  }
}
