import { Controller } from '@hotwired/stimulus';

type ColorPalette = 'modern' | 'classic';

export default class extends Controller<HTMLElement> {
  static readonly targets = ['inputClassic', 'inputModern'];

  declare readonly inputClassicTargets: HTMLInputElement[];
  declare readonly inputModernTargets: HTMLInputElement[];

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

  classic() {
    this.colorPalette = 'classic';
    this.apply();
  }

  modern() {
    this.colorPalette = 'modern';
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
    for (const input of this.inputClassicTargets) {
      input.checked = this.colorPalette === 'classic';
    }

    for (const input of this.inputModernTargets) {
      input.checked = this.colorPalette === 'modern';
    }
  }

  private updateHtmlClass() {
    document.documentElement.classList.toggle(
      'palette-modern',
      this.colorPalette === 'modern',
    );
  }

  get colorPalette(): ColorPalette {
    const stored = localStorage.getItem('colorPalette');
    if (stored === 'modern') return 'modern';
    return 'classic';
  }

  set colorPalette(value: ColorPalette) {
    if (value === 'classic') {
      localStorage.removeItem('colorPalette');
      return;
    }
    localStorage.setItem('colorPalette', value);
  }
}
