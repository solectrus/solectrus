import { Controller } from '@hotwired/stimulus';
import tippy from 'tippy.js';

export default class extends Controller {
  static values = {
    placement: {
      type: String,
      default: 'bottom',
    },
  };
  static targets = ['html'];

  connect() {
    tippy(this.element, {
      allowHTML: true,
      arrow: true,
      placement: this.placementValue,
      theme: 'light-border',
      animation: 'scale',
      content: (reference) => {
        const title = reference.getAttribute('title');

        if (title) {
          // Remove title from DOM element to avoid native browser tooltips
          reference.removeAttribute('title');

          return title;
        }
        if (this.hasHtmlTarget) return this.htmlTarget.innerHTML;
      },
    });
  }

  disconnect() {
    this.element._tippy.destroy();
  }
}
