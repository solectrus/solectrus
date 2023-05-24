import { Controller } from '@hotwired/stimulus';
import tippy, { BasePlacement, Instance } from 'tippy.js';

export default class extends Controller {
  static values = {
    // Where to place the tooltip relative to the target element
    placement: {
      type: String,
      default: 'bottom',
    },

    // Show tooltip only on non-touch devices
    nonTouchOnly: {
      type: Boolean,
      default: false,
    },
  };

  declare placementValue: BasePlacement;
  declare nonTouchOnlyValue: boolean;

  static targets = ['html'];

  declare readonly hasHtmlTarget: boolean;
  declare readonly htmlTarget: HTMLElement;
  declare readonly htmlTargets: HTMLElement[];

  private instance: Instance | undefined;
  private onClick: ((event: Event) => void) | undefined;

  connect() {
    if (this.nonTouchOnlyValue && 'ontouchstart' in window) return;

    const title = this.element.getAttribute('title');
    const content = (this.hasHtmlTarget && this.htmlTarget.innerHTML) || title;
    if (!content) return;

    this.instance = tippy(this.element, {
      content,
      allowHTML: true,
      arrow: true,
      placement: this.placementValue,
      theme: 'light-border',
      animation: 'scale',
      hideOnClick: false,
    });

    // Remove title from DOM element to avoid native browser tooltips
    this.element.removeAttribute('title');

    // Set aria-label to keep a discernible text
    this.element.ariaLabel = title;
  }

  disconnect() {
    if (this.instance) this.instance.destroy();

    // Remove click listener
    if (this.onClick) this.element.removeEventListener('click', this.onClick);
  }
}
