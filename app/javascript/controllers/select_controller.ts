import { Controller } from '@hotwired/stimulus';
import * as Turbo from '@hotwired/turbo';

export default class extends Controller<HTMLSelectElement> {
  onChange() {
    Turbo.visit(this.element.value);
  }
}
