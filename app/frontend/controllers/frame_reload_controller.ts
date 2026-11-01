import { Controller } from '@hotwired/stimulus';
import type { FrameElement } from '@hotwired/turbo';

// Loads its Turbo frame again, for example after a save in the modal:
// data-action="ui--turbo-modal--component:changed@document->frame-reload#reload"
export default class extends Controller<FrameElement> {
  reload(): void {
    this.element.reload();
  }
}
