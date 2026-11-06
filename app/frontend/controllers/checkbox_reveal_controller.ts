import { Controller } from '@hotwired/stimulus';

// Shows a part of a form only while a checkbox is checked, before the form is
// saved. A part that hides is unchecked, so it comes back unchecked: the
// server starts it off as well when the checkbox is checked again.
export default class extends Controller {
  static readonly targets = ['switch', 'part'];

  declare readonly switchTarget: HTMLInputElement;
  declare readonly partTargets: HTMLElement[];

  connect() {
    this.update();
  }

  update() {
    const on = this.switchTarget.checked;

    for (const part of this.partTargets) {
      part.hidden = !on;
      if (on) continue;

      for (const input of part.querySelectorAll<HTMLInputElement>(
        'input[type=checkbox]',
      )) {
        input.checked = false;
      }
    }
  }
}
