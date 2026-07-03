import { Controller } from '@hotwired/stimulus';

// Submits the form as soon as a control changes - for toggles that persist
// immediately, without a dedicated save button.
export default class extends Controller<HTMLFormElement> {
  submit() {
    this.element.requestSubmit();
  }
}
