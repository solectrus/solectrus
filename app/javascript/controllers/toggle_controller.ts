import { Controller } from '@hotwired/stimulus';

export default class extends Controller {
  static readonly targets = ['dropdown', 'button', 'icon'];

  static readonly values = {
    maxHeightClass: { type: String, default: 'max-h-192' },
  };

  declare readonly dropdownTarget: HTMLElement;
  declare readonly buttonTarget: HTMLElement;
  declare readonly iconTargets: HTMLElement[];

  declare readonly maxHeightClassValue: string;

  hide() {
    if (this.buttonTarget.ariaExpanded === 'true') this.toggle();
  }

  toggle() {
    this.dropdownTarget.classList.toggle('max-h-0');
    this.dropdownTarget.classList.toggle(this.maxHeightClassValue);

    this.iconTargets.forEach((icon) => icon.classList.toggle('hidden'));

    this.buttonTarget.ariaExpanded =
      this.buttonTarget.ariaExpanded === 'true' ? 'false' : 'true';
  }
}
