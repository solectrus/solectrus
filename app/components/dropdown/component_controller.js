// Based on https://dev.to/mmccall10/tailwind-enter-leave-transition-effects-with-stimulus-js-5hl7

import { Controller } from 'stimulus';
import { enter, leave } from 'el-transition';

export default class extends Controller {
  static targets = ['menu', 'button'];

  connect() {
    document.addEventListener('click', this.handleClickOutside.bind(this));
  }

  disconnect() {
    document.removeEventListener('click', this.handleClickOutside.bind(this));
  }

  toggleMenu() {
    if (this.menuTarget.classList.contains('hidden')) {
      enter(this.menuTarget);
    } else {
      leave(this.menuTarget);
    }
  }

  handleClickOutside(event) {
    const menuClicked = this.menuTarget.contains(event.target);
    const buttonClicked = this.buttonTarget.contains(event.target);
    const hidden = this.menuTarget.classList.contains('hidden');

    if (!menuClicked && !buttonClicked && !hidden) {
      leave(this.menuTarget);
    }
  }
}
