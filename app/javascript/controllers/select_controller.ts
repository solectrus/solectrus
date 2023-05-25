import { Controller } from '@hotwired/stimulus';
import * as Turbo from '@hotwired/turbo';

export default class extends Controller<HTMLSelectElement> {
  static targets = ['select', 'temp'];

  declare readonly selectTarget: HTMLSelectElement;
  declare readonly tempTarget: HTMLSelectElement;

  connect() {
    this.autoWidth();
  }

  onChange() {
    Turbo.visit(this.selectTarget.value, this.selectedTurboOptions());
  }

  autoWidth() {
    this.selectTarget.style.width = `${this.widthOfSelectedOption}px`;
  }

  // Hack to get the width of the selected option
  get widthOfSelectedOption() {
    // Get the text of the selected option
    const text =
      this.selectTarget.options[this.selectTarget.selectedIndex].text;

    // Use a temporary select which has just ONE option - the selected one
    this.tempTarget.innerHTML = `<option selected>${text}</option>`;

    // Return the width of the temporary select
    return this.tempTarget.clientWidth;
  }

  selectedTurboOptions() {
    // Get the currently selected option
    const selectedOption =
      this.selectTarget.options[this.selectTarget.selectedIndex];

    // Get the data attributes of the selected option
    const dataValue = selectedOption.dataset;

    // Transform the data attributes to the format Turbo expects
    // Examples:
    //  dataTurboAction -> action
    //  dataTurboFrame -> frame
    const transformedDataValue: Partial<{ [key: string]: string }> = {};
    for (const key in dataValue) {
      if (key.startsWith('turbo')) {
        const attributeName = key.replace('turbo', '').toLowerCase();
        transformedDataValue[attributeName] = dataValue[key];
      }
    }

    return transformedDataValue;
  }
}
