import { Controller } from '@hotwired/stimulus';

// The map of the location of a car over the live view. The close button and
// ESC empty its frame, so the live view shows again.
export default class extends Controller<HTMLElement> {
  connect() {
    document.addEventListener('keydown', this.handleKeydown);
  }

  disconnect() {
    document.removeEventListener('keydown', this.handleKeydown);
  }

  close() {
    const frame = this.element.closest('turbo-frame');
    if (!frame) return;

    // Without its src, the next click loads the frame again
    frame.removeAttribute('src');
    frame.replaceChildren();
  }

  // The open attribution of the map takes ESC first
  private readonly handleKeydown = (event: KeyboardEvent) => {
    if (event.key !== 'Escape' || event.defaultPrevented) return;

    this.close();
  };
}
