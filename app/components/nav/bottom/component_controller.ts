import { Controller } from '@hotwired/stimulus';

export default class extends Controller {
  static readonly targets = ['dropdown', 'button', 'icon'];

  static readonly values = {
    heightClass: { type: String, default: 'h-auto' },
  };

  declare readonly dropdownTarget: HTMLElement;
  declare readonly buttonTargets: HTMLElement[];
  declare readonly iconTargets: HTMLElement[];
  declare readonly heightClassValue: string;

  hide() {
    if (this.buttonTargets[0]?.ariaExpanded === 'true') this.toggle();
  }

  toggle() {
    this.dropdownTarget.classList.toggle('h-0');
    this.dropdownTarget.classList.toggle(this.heightClassValue);

    for (const icon of this.iconTargets) {
      icon.classList.toggle('hidden');
    }

    for (const button of this.buttonTargets) {
      button.ariaExpanded = button.ariaExpanded === 'true' ? 'false' : 'true';
    }
  }
}
