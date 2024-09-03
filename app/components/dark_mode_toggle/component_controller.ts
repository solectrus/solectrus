import { Controller } from '@hotwired/stimulus';

export default class extends Controller<HTMLElement> {
  static readonly targets = ['button'];

  static readonly values = {
    dark: { type: String },
    light: { type: String },
  };

  declare readonly buttonTarget: HTMLButtonElement;

  declare readonly darkValue: string;
  declare readonly lightValue: string;

  connect(): void {
    if (this.preference) document.documentElement.classList.add('dark');
    this.updateTooltip();
  }

  toggle() {
    this.apply(!this.isCurrentlyDark);
  }

  apply(isDark: boolean) {
    if (isDark) document.documentElement.classList.add('dark');
    else document.documentElement.classList.remove('dark');

    this.preference = isDark;
    this.updateTooltip();
  }

  updateTooltip() {
    // Remove tippy controller
    this.buttonTarget.removeAttribute('data-controller');

    // Set new button title
    this.buttonTarget.title = this.isCurrentlyDark
      ? this.lightValue
      : this.darkValue;

    // Re-add tippy controller, so the new title is used
    setTimeout(() => {
      this.buttonTarget.dataset.controller = 'tippy';
    }, 0);
  }

  get isCurrentlyDark(): boolean {
    return document.documentElement.classList.contains('dark');
  }

  get preference() {
    return (
      localStorage.getItem('dark-mode') === 'true' ||
      (!('dark-mode' in localStorage) &&
        window.matchMedia('(prefers-color-scheme: dark)').matches)
    );
  }

  set preference(isDark: boolean) {
    localStorage.setItem('dark-mode', isDark ? 'true' : 'false');
  }
}
