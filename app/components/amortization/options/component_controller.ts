import { Controller } from '@hotwired/stimulus';
import { BottomSheet } from '@/utils/bottomSheet';

// Opens the sliders of the calculation in a sheet. The sheet closes on its
// own (utils/bottomSheet.ts), and a slider submits as it did in the bar.
export default class extends Controller<HTMLElement> {
  static targets = ['dialog'];
  declare readonly dialogTarget: HTMLDialogElement;

  declare sheet: BottomSheet | null;

  connect() {
    this.sheet = new BottomSheet(this.dialogTarget);
  }

  disconnect() {
    this.sheet?.destroy();
    this.sheet = null;
  }

  open() {
    this.sheet?.open();
  }
}
