import { Controller } from '@hotwired/stimulus';
import autoAnimate, { type AnimationController } from '@formkit/auto-animate';

export default class extends Controller {
  static readonly targets = ['segments', 'table', 'icon'];
  static readonly values = { key: { type: String, default: 'viewMode' } };

  declare readonly segmentsTarget: HTMLElement;
  declare readonly tableTarget: HTMLElement;
  declare readonly iconTargets: HTMLElement[];
  declare readonly keyValue: string;

  private animateControls = new Map<HTMLElement, AnimationController>();

  connect() {
    this.restoreMode();
    this.element.addEventListener(
      'turbo:before-morph-element',
      this.preserveHidden,
    );
  }

  disconnect() {
    this.element.removeEventListener(
      'turbo:before-morph-element',
      this.preserveHidden,
    );
    this.disableAutoAnimate();
  }

  toggle() {
    const showTable = !this.segmentsTarget.classList.contains('hidden');
    this.setMode(showTable);
    localStorage.setItem(this.keyValue, showTable ? 'table' : 'segments');
  }

  private preserveHidden = (event: Event) => {
    const el = event.target as HTMLElement;
    const newEl = (event as CustomEvent).detail?.newElement as HTMLElement;
    if (
      newEl &&
      el.classList.contains('hidden') !== newEl.classList.contains('hidden')
    )
      newEl.classList.toggle('hidden', el.classList.contains('hidden'));
  };

  private restoreMode() {
    const showTable = this.storedMode === 'table';
    if (showTable) this.setMode(true);
    else this.enableAutoAnimate(this.segmentsTarget, '.divide-y', 1000);
  }

  private setMode(showTable: boolean) {
    this.segmentsTarget.classList.toggle('hidden', showTable);
    this.tableTarget.classList.toggle('hidden', !showTable);
    for (const icon of this.iconTargets) icon.classList.toggle('hidden');

    this.disableAutoAnimate();
    if (showTable)
      this.enableAutoAnimate(this.tableTarget, '.overflow-y-auto', 700);
    else this.enableAutoAnimate(this.segmentsTarget, '.divide-y', 1000);
  }

  private enableAutoAnimate(
    target: HTMLElement,
    selector: string,
    duration: number,
  ) {
    if (this.animateControls.has(target)) return;

    const list = target.querySelector(selector);
    if (list instanceof HTMLElement)
      this.animateControls.set(target, autoAnimate(list, { duration }));
  }

  private disableAutoAnimate() {
    for (const controls of this.animateControls.values()) controls.disable();
    this.animateControls.clear();
  }

  private get storedMode(): string | null {
    return localStorage.getItem(this.keyValue);
  }
}
