import { Controller } from '@hotwired/stimulus';
import * as Turbo from '@hotwired/turbo';

export default class extends Controller {
  static readonly targets = ['bar'];
  declare readonly barTargets: HTMLDivElement[];

  observer!: MutationObserver;

  connect() {
    // Initialize the MutationObserver to watch for changes in the child elements
    this.observer = new MutationObserver(this.checkCompletion.bind(this));

    // Observe the current element to catch when the child elements (bars) are replaced
    this.observer.observe(this.element, {
      childList: true, // Watch for child element additions/removals
      subtree: true, // Watch all descendants of this element
    });

    this.checkCompletion();
  }

  disconnect() {
    if (this.observer) {
      this.observer.disconnect();
    }
  }

  checkCompletion() {
    const allComplete = this.barTargets.every(
      (bar) => bar.dataset.complete != undefined,
    );

    if (allComplete) {
      Turbo.visit(window.location.href, { action: 'replace' });
    }
  }
}
