import { Controller } from '@hotwired/stimulus';
import { isTouchEnabled } from '@/utils/device';

export default class extends Controller<HTMLElement> {
  private readonly swipeThreshold: number = 50; // Minimum distance in pixels for a swipe
  private readonly swipeTimeThreshold: number = 300; // Maximum duration in milliseconds for a swipe

  private touchStartX: number = 0;
  private touchEndX: number = 0;
  private touchStartTime: number = 0;
  private touchEndTime: number = 0;

  connect() {
    if (!isTouchEnabled()) return;
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

  handleTouchStart(event: TouchEvent) {
    // Record the starting position and time of the touch event
    this.touchStartX = event.changedTouches[0].screenX;
    this.touchStartTime = new Date().getTime();
  }

  handleTouchEnd(event: TouchEvent) {
    // Record the ending position of the touch event
    this.touchEndX = event.changedTouches[0].screenX;
    this.touchEndTime = new Date().getTime();

    if (this.isSwipe()) {
      this.doSwipe(event);
    }
  }

  isSwipe(): boolean {
    const deltaX = this.touchEndX - this.touchStartX;
    const touchDuration = this.touchEndTime - this.touchStartTime;

    // Check if the gesture meets the distance threshold and is within the time threshold
    return (
      Math.abs(deltaX) > this.swipeThreshold &&
      touchDuration <= this.swipeTimeThreshold
    );
  }

  doSwipe(event: TouchEvent) {
    const deltaX = this.touchEndX - this.touchStartX;

    if (deltaX < 0) {
      this.swipeLeft();
    } else {
      this.swipeRight();
    }

    // Prevent default behavior if a swipe is recognized
    event.preventDefault();
  }

  swipeLeft() {
    const nextLink = document.querySelector<HTMLAnchorElement>('a[rel="next"]');
    if (nextLink) {
      nextLink.click();
    }
  }

  swipeRight() {
    const prevLink = document.querySelector<HTMLAnchorElement>('a[rel="prev"]');
    if (prevLink) {
      prevLink.click();
    }
  }

  disconnect() {
    if (!isTouchEnabled()) return;

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
