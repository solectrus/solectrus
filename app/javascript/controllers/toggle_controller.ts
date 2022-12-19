import { Controller } from '@hotwired/stimulus';

export default class extends Controller {
  static targets = ['element'];

  declare readonly hasElementTarget: boolean;
  declare readonly elementTarget: HTMLElement;
  declare readonly elementTargets: HTMLElement[];

  toggle(event: Event) {
    event.preventDefault();

    this.elementTargets.forEach((element) => {
      if (element.classList.contains('hidden')) {
        element.classList.remove('hidden');
        element.classList.add('block');
      } else {
        element.classList.add('hidden');
        element.classList.remove('block');
      }
    });
  }
}
