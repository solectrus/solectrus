import { Controller } from '@hotwired/stimulus';
import {
  computePosition,
  flip,
  shift,
  offset,
  autoUpdate,
} from '@floating-ui/dom';

// A dropdown of checkboxes that behaves like a multi-select. The summary button
// shows the current selection; the panel opens on click and closes on outside
// click or Escape. The form is submitted once when the panel closes (not on
// every toggle), so several options can be picked in one go without a reload
// after each click.
//
// The panel is positioned with Floating UI in the fixed strategy so it escapes
// the surrounding card's `overflow-hidden` clipping (and paints above the
// footer) while staying inside the form for submission.
export default class extends Controller<HTMLElement> {
  static readonly targets = ['panel', 'button', 'label', 'checkbox'];
  static readonly values = {
    placeholder: String,
    countLabel: String, // "%{count}" template for two or more selections
  };

  declare readonly panelTarget: HTMLElement;
  declare readonly buttonTarget: HTMLElement;
  declare readonly labelTarget: HTMLElement;
  declare readonly checkboxTargets: HTMLInputElement[];
  declare readonly placeholderValue: string;
  declare readonly countLabelValue: string;

  private dirty = false;
  private positionCleanup: (() => void) | null = null;

  private readonly onOutsideClick = (event: MouseEvent) => {
    if (!this.element.contains(event.target as Node)) this.close();
  };

  private readonly onKeydown = (event: KeyboardEvent) => {
    if (event.key === 'Escape') this.close();
  };

  connect() {
    this.updateLabel();
  }

  disconnect() {
    this.stopListening();
    this.positionCleanup?.();
    this.positionCleanup = null;
  }

  toggle(event: Event) {
    event.preventDefault();
    if (this.panelTarget.hidden) this.open();
    else this.close();
  }

  open() {
    if (!this.panelTarget.hidden) return;

    this.panelTarget.hidden = false;
    this.panelTarget.style.position = 'fixed';
    this.panelTarget.style.zIndex = '50';
    this.panelTarget.style.minWidth = `${this.buttonTarget.offsetWidth}px`;

    this.positionCleanup = autoUpdate(this.buttonTarget, this.panelTarget, () =>
      this.reposition(),
    );

    document.addEventListener('click', this.onOutsideClick);
    document.addEventListener('keydown', this.onKeydown);
  }

  close() {
    if (this.panelTarget.hidden) return;

    this.panelTarget.hidden = true;
    this.positionCleanup?.();
    this.positionCleanup = null;
    this.stopListening();

    // Submit only when the selection actually changed while open.
    if (this.dirty) {
      this.dirty = false;
      this.element.closest('form')?.requestSubmit();
    }
  }

  change() {
    this.dirty = true;
    this.updateLabel();
  }

  private async reposition() {
    const { x, y } = await computePosition(
      this.buttonTarget,
      this.panelTarget,
      {
        placement: 'bottom-start',
        strategy: 'fixed',
        middleware: [offset(4), flip(), shift({ padding: 8 })],
      },
    );
    Object.assign(this.panelTarget.style, { left: `${x}px`, top: `${y}px` });
  }

  private stopListening() {
    document.removeEventListener('click', this.onOutsideClick);
    document.removeEventListener('keydown', this.onKeydown);
  }

  private updateLabel() {
    const checked = this.checkboxTargets.filter((checkbox) => checkbox.checked);

    if (checked.length === 0) {
      this.labelTarget.textContent = this.placeholderValue;
    } else if (checked.length === 1) {
      this.labelTarget.textContent = checked[0].dataset.label ?? '';
    } else {
      this.labelTarget.textContent = this.countLabelValue.replace(
        '%{count}',
        String(checked.length),
      );
    }
  }
}
