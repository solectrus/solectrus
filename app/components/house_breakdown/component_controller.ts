import { Controller } from '@hotwired/stimulus';
import autoAnimate, { type AnimationController } from '@formkit/auto-animate';

type ViewMode = 'segments' | 'table';

export default class extends Controller {
  static readonly targets = ['segments', 'table', 'icon'];
  static readonly values = { key: { type: String, default: 'viewMode' } };

  declare readonly segmentsTarget: HTMLElement;
  declare readonly tableTarget: HTMLElement;
  declare readonly iconTargets: HTMLElement[];
  declare readonly keyValue: string;

  private animateController: AnimationController | null = null;

  connect() {
    this.setMode(this.storedMode);
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
    const mode: ViewMode =
      this.currentMode === 'segments' ? 'table' : 'segments';
    localStorage.setItem(this.keyValue, mode);
    this.setMode(mode);
  }

  iconTargetConnected() {
    // Icons connect after restoreMode(), so apply the current mode directly
    // from the DOM state rather than re-reading localStorage
    this.applyIcons(this.currentMode);
  }

  private preserveHidden = (event: Event) => {
    const newEl = (event as CustomEvent).detail?.newElement as HTMLElement;
    if (newEl)
      newEl.classList.toggle(
        'hidden',
        (event.target as HTMLElement).classList.contains('hidden'),
      );
  };

  private applyIcons(mode: ViewMode) {
    const [segmentsIcon, tableIcon] = this.iconTargets;
    if (segmentsIcon) segmentsIcon.classList.toggle('hidden', mode === 'table');
    if (tableIcon) tableIcon.classList.toggle('hidden', mode === 'segments');
  }

  private setMode(mode: ViewMode) {
    this.segmentsTarget.classList.toggle('hidden', mode === 'table');
    this.tableTarget.classList.toggle('hidden', mode === 'segments');
    this.applyIcons(mode);

    this.disableAutoAnimate();
    const target = mode === 'table' ? this.tableTarget : this.segmentsTarget;
    const list = target.querySelector(
      mode === 'table' ? '.overflow-y-auto' : '.divide-y',
    );
    if (list instanceof HTMLElement)
      this.animateController = autoAnimate(list, {
        duration: mode === 'table' ? 700 : 1000,
      });
  }

  private disableAutoAnimate() {
    this.animateController?.disable();
    this.animateController = null;
  }

  private get currentMode(): ViewMode {
    return this.segmentsTarget.classList.contains('hidden')
      ? 'table'
      : 'segments';
  }

  private get storedMode(): ViewMode {
    return localStorage.getItem(this.keyValue) === 'table'
      ? 'table'
      : 'segments';
  }
}
