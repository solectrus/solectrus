import { Controller } from '@hotwired/stimulus';
import { enter, leave } from 'el-transition';

export default class extends Controller {
  static readonly targets = ['outer', 'panel', 'overlay'];

  declare readonly outerTarget: HTMLElement;
  declare readonly panelTarget: HTMLElement;
  declare readonly overlayTarget: HTMLElement;
  isOpen: boolean = false;

  toggle() {
    this.isOpen = !this.isOpen;

    if (this.isOpen) this.close();
    else this.open();
  }

  open() {
    this.outerTarget.classList.remove('hidden');

    enter(this.panelTarget);
    enter(this.overlayTarget);
  }

  close() {
    leave(this.panelTarget);
    leave(this.overlayTarget).then(() => {
      this.outerTarget.classList.add('hidden');
    });
  }
}
