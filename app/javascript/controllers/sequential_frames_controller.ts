import { Controller } from '@hotwired/stimulus';
import * as Turbo from '@hotwired/turbo';

export default class extends Controller {
  static readonly targets = ['frame'];

  declare readonly frameTarget: Turbo.FrameElement;
  declare readonly frameTargets: Turbo.FrameElement[];

  connect() {
    this.loadNextFrame(0);
  }

  loadNextFrame(index: number) {
    const frame = this.frameTargets[index];

    if (frame) {
      frame.addEventListener(
        'turbo:frame-load',
        () => this.loadNextFrame(index + 1),
        { once: true },
      );
      frame.src = frame.dataset.src;
    }
  }
}
