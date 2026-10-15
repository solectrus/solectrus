import { Controller } from '@hotwired/stimulus';

export default class extends Controller<HTMLElement> {
  static targets = ['optionCell'];

  declare readonly optionCellTargets: HTMLButtonElement[];

  selectOption(event: Event) {
    const button = event.currentTarget as HTMLButtonElement;
    const value = button.dataset.value;
    if (!value) return;

    window.dispatchEvent(
      new CustomEvent('picker:selected', {
        detail: { value, isRange: false },
      }),
    );
  }
}
