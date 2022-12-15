import { Controller } from '@hotwired/stimulus';
import tippy, { BasePlacement, Instance } from 'tippy.js';

export default class extends Controller {
  static values = {
    placement: {
      type: String,
      default: 'bottom',
    },
  };

  static targets = ['html'];

  declare placementValue: BasePlacement;
  declare readonly hasPlacementValue: boolean;

  declare readonly hasHtmlTarget: boolean;
  declare readonly htmlTarget: HTMLElement;
  declare readonly htmlTargets: HTMLElement[];

  private instance: Instance | undefined;

  connect() {
    const content =
      (this.hasHtmlTarget && this.htmlTarget.innerHTML) ||
      this.element.getAttribute('title');
    if (!content) return;

    this.instance = tippy(this.element, {
      content,
      allowHTML: true,
      arrow: true,
      placement: this.placementValue,
      theme: 'light-border',
      animation: 'scale',
    });

    // Remove title from DOM element to avoid native browser tooltips
    this.element.removeAttribute('title');
  }

  disconnect() {
    if (this.instance) this.instance.destroy();
  }
}
