import { Controller } from '@hotwired/stimulus';
import tippy, { BasePlacement, Instance } from 'tippy.js';

export default class extends Controller {
  static readonly values = {
    // Where to place the tooltip relative to the target element
    placement: {
      type: String,
      default: 'bottom',
    },

    // How to handle tooltips on touch devices, can be "true", "false" or "long"
    touch: {
      type: String,
      default: 'false',
    },

    // Force second tap (on touch device) to close tooltip
    forceTapToClose: {
      type: Boolean,
      default: true,
    },
  };

  declare placementValue: BasePlacement;
  declare touchValue: 'true' | 'false' | 'long';
  declare forceTapToCloseValue: boolean;

  static readonly targets = ['html'];

  declare readonly hasHtmlTarget: boolean;
  declare readonly htmlTarget: HTMLElement;
  declare readonly htmlTargets: HTMLElement[];

  private instance: Instance | undefined;

  connect() {
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
      inertia: true,
      hideOnClick: false,
      touch: this.touch,

      // Prevent click on tooltip from triggering click on target
      onShown: () => this.toggleActiveTippy(true),
      onHidden: () => this.toggleActiveTippy(false),
    });

    // Remove title from DOM element to avoid native browser tooltips
    this.element.removeAttribute('title');

    // Set aria-label to keep a discernible text
    this.element.ariaLabel = title;
  }

  disconnect() {
    if (this.instance) this.instance.destroy();
  }

  refresh() {
    if (!this.instance) return;

    const title = this.element.getAttribute('title');
    if (title) {
      // Remove title from DOM element to avoid native browser tooltips
      this.element.removeAttribute('title');

      // Set aria-label to keep a discernible text
      this.element.ariaLabel = title;
    }

    const content =
      (this.hasHtmlTarget && this.htmlTarget.innerHTML) ||
      this.element.ariaLabel ||
      '';

    this.instance.setContent(content);
  }

  toggleActiveTippy = (value: boolean) => {
    if (!this.isTouchDevice) return;
    if (!this.forceTapToCloseValue) return;

    document.body.classList.toggle('active-tippy', value);
  };

  get isTouchDevice(): boolean {
    return 'ontouchstart' in window;
  }

  get touch(): boolean | ['hold', number] {
    switch (this.touchValue) {
      case 'true':
        return true;
      case 'false':
        return false;
      case 'long':
        return ['hold', 500];
      default:
        return false;
    }
  }
}
