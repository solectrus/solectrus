import { Controller } from '@hotwired/stimulus';

export default class extends Controller {
  static readonly targets = ['dropdown', 'button', 'icon'];

  declare readonly dropdownTarget: HTMLElement;
  declare readonly buttonTarget: HTMLElement;
  declare readonly iconTargets: HTMLElement[];

  hide() {
    if (this.buttonTarget.ariaExpanded === 'true') this.toggle();
  }

  toggle() {
    this.dropdownTarget.classList.toggle('max-h-0');
    this.dropdownTarget.classList.toggle('max-h-128');

    this.iconTargets.forEach((icon) => icon.classList.toggle('hidden'));

    this.buttonTarget.ariaExpanded =
      this.buttonTarget.ariaExpanded === 'true' ? 'false' : 'true';
  }
}
