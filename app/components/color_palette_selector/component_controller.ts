import { Controller } from '@hotwired/stimulus';

type ColorPalette = 'contrast' | 'standard';

export default class extends Controller<HTMLElement> {
  static readonly targets = ['inputStandard', 'inputContrast'];

  declare readonly inputStandardTargets: HTMLInputElement[];
  declare readonly inputContrastTargets: HTMLInputElement[];

  private boundHandleMorph?: () => void;

  connect() {
    this.updateButtons();
    this.updateHtmlClass();

    this.boundHandleMorph = this.updateButtons.bind(this);
    document.addEventListener('turbo:morph', this.boundHandleMorph);
  }

  disconnect() {
    if (this.boundHandleMorph)
      document.removeEventListener('turbo:morph', this.boundHandleMorph);
  }

  standard() {
    this.colorPalette = 'standard';
    this.apply();
  }

  contrast() {
    this.colorPalette = 'contrast';
    this.apply();
  }

  private apply() {
    this.updateHtmlClass();

    document.dispatchEvent(
      new CustomEvent('theme:changed', {
        detail: { colorPalette: this.colorPalette },
      }),
    );
  }

  private updateButtons() {
    for (const input of this.inputStandardTargets) {
      input.checked = this.colorPalette === 'standard';
    }

    for (const input of this.inputContrastTargets) {
      input.checked = this.colorPalette === 'contrast';
    }
  }

  private updateHtmlClass() {
    document.documentElement.classList.toggle(
      'palette-contrast',
      this.colorPalette === 'contrast',
    );
  }

  get colorPalette(): ColorPalette {
    const stored = localStorage.getItem('colorPalette');
    if (stored === 'contrast') return 'contrast';
    return 'standard';
  }

  set colorPalette(value: ColorPalette) {
    if (value === 'standard') {
      localStorage.removeItem('colorPalette');
      return;
    }
    localStorage.setItem('colorPalette', value);
  }
}
