// Based on https://dev.to/mmccall10/tailwind-enter-leave-transition-effects-with-stimulus-js-5hl7

import { Controller } from '@hotwired/stimulus';
import { enter, leave } from 'el-transition';

export default class extends Controller {
  static readonly targets = ['menu', 'button'];

  declare readonly hasMenuTarget: boolean;
  declare readonly menuTarget: HTMLElement;
  declare readonly menuTargets: HTMLElement[];

  declare readonly hasButtonTarget: boolean;
  declare readonly buttonTarget: HTMLElement;
  declare readonly buttonTargets: HTMLElement[];

  connect() {
    document.addEventListener('click', this.handleClickOutside.bind(this));
  }

  disconnect() {
    document.removeEventListener('click', this.handleClickOutside.bind(this));
  }

  toggle() {
    if (this.menuTarget.classList.contains('hidden')) {
      enter(this.menuTarget);
      this.buttonTarget.ariaExpanded = 'true';
    } else {
      leave(this.menuTarget);
      this.buttonTarget.ariaExpanded = 'false';
    }
  }

  handleClickOutside(event: Event) {
    if (!(event.target instanceof HTMLElement)) return;

    const menuClicked = this.menuTarget.contains(event.target);
    const buttonClicked = this.buttonTarget.contains(event.target);
    const hidden = this.menuTarget.classList.contains('hidden');

    if (!menuClicked && !buttonClicked && !hidden) {
      leave(this.menuTarget);
    }
  }
}
