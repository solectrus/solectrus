import { Controller } from '@hotwired/stimulus';

export default class extends Controller {
  connect() {
    this.touchStartX = 0;
    this.touchEndX = 0;

    this.element.addEventListener(
      'touchstart',
      this.handleTouchStart.bind(this),
      false,
    );
    this.element.addEventListener(
      'touchend',
      this.handleTouchEnd.bind(this),
      false,
    );
  }

  handleTouchStart(event) {
    this.touchStartX = event.changedTouches[0].screenX;
  }

  handleTouchEnd(event) {
    this.touchEndX = event.changedTouches[0].screenX;
    this.handleGesture();
  }

  handleGesture() {
    if (this.touchEndX < this.touchStartX) {
      this.swipeLeft();
    } else if (this.touchEndX > this.touchStartX) {
      this.swipeRight();
    }
  }

  swipeLeft() {
    const nextLink = document.querySelector('[rel="next"]');
    if (nextLink) {
      nextLink.click();
    }
  }

  swipeRight() {
    const prevLink = document.querySelector('[rel="prev"]');
    if (prevLink) {
      prevLink.click();
    }
  }

  disconnect() {
    this.element.removeEventListener(
      'touchstart',
      this.handleTouchStart.bind(this),
    );
    this.element.removeEventListener(
      'touchend',
      this.handleTouchEnd.bind(this),
    );
  }
}
