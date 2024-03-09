import { Controller } from '@hotwired/stimulus';

export default class extends Controller<HTMLSelectElement> {
  static targets = ['select', 'temp'];

  declare readonly selectTarget: HTMLSelectElement;
  declare readonly tempTarget: HTMLSelectElement;

  connect() {
    this.autoWidth();
  }

  onChange() {
    // Sadly, we can't use Turbo.visit() here, because it doesn't support
    // dispatching Aaction and ActionParameter options. So we have to do
    // a full page refresh
    location.href = this.selectTarget.value;
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
}
