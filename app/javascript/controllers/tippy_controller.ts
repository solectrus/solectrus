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
    this.instance = tippy(this.element, {
      allowHTML: true,
      arrow: true,
      placement: this.placementValue,
      theme: 'light-border',
      animation: 'scale',
      content: (reference): string => {
        const title = reference.getAttribute('title');

        if (title) {
          // Remove title from DOM element to avoid native browser tooltips
          reference.removeAttribute('title');

          return title;
        }

        if (this.hasHtmlTarget) return this.htmlTarget.innerHTML;

        throw new Error('Tippy: No title or html target found!');
      },
    });
  }

  disconnect() {
    if (this.instance) this.instance.destroy();
  }
}
