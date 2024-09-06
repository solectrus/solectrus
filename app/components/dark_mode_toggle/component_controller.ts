import { Controller } from '@hotwired/stimulus';

export default class extends Controller<HTMLElement> {
  static readonly targets = ['button'];

  static readonly values = {
    dark: { type: String, default: 'Dark mode' },
    light: { type: String, default: 'Light mode' },
  };

  declare readonly buttonTarget: HTMLButtonElement;
  declare readonly darkValue: string;
  declare readonly lightValue: string;

  readonly darkThemeColor = '#1e1b4b';
  readonly lightThemeColor = '#a5b4fc';
  private isCurrentlyDark = false;

  connect() {
    this.isCurrentlyDark = this.preference;
    this.apply();
  }

  toggle() {
    this.isCurrentlyDark = !this.isCurrentlyDark;
    this.apply();
  }

  apply() {
    this.updateHtmlClass();
    this.updateTooltip();
    this.updateThemeColor();

    this.preference = this.isCurrentlyDark;
  }

  updateHtmlClass() {
    if (this.isCurrentlyDark) {
      document.documentElement.classList.add('dark');
    } else {
      document.documentElement.classList.remove('dark');
    }
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

  updateThemeColor() {
    const color = this.isCurrentlyDark
      ? this.darkThemeColor
      : this.lightThemeColor;

    const themeMetaTag = document.querySelector('meta[name="theme-color"]');
    if (themeMetaTag) {
      themeMetaTag.setAttribute('content', color);
    }
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
