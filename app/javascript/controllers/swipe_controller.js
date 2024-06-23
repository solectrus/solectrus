import { Controller } from '@hotwired/stimulus';
import Hammer from 'hammerjs';

export default class extends Controller {
  connect() {
    const hammer = new Hammer(this.element);

    hammer.on('swiperight', () => {
      const prevLink = document.querySelector('[rel="prev"]');
      if (prevLink) {
        prevLink.click();
      }
    });

    hammer.on('swipeleft', () => {
      const nextLink = document.querySelector('[rel="next"]');
      if (nextLink) {
        nextLink.click();
      }
    });
  }

  disconnect() {
    const hammer = Hammer(this.element);
    hammer.off('swiperight swipeleft');
  }
}
