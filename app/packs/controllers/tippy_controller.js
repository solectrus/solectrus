import { Controller } from 'stimulus';

import tippy from 'tippy.js';
import 'tippy.js/dist/tippy.css';
import 'tippy.js/animations/scale.css';
import 'tippy.js/themes/light-border.css';

export default class extends Controller {
  static targets = ['html'];

  connect() {
    this.tippyInstance = tippy(this.element, {
      allowHTML: true,
      arrow: true,
      placement: 'bottom',
      theme: 'light-border',
      animation: 'scale',
      content: (reference) => {
        const title = reference.getAttribute('title');

        if (title) {
          // Remove title from DOM element to avoid native browser tooltips
          reference.removeAttribute('title');

          return title;
        } else if (this.hasHtmlTarget) return this.htmlTarget.innerHTML;
        else console.warn('TippyController: Title or HTML target required!');
      },
    });
  }

  disconnect() {
    this.tippyInstance.destroy();
  }
}
