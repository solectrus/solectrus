import { Controller } from '@hotwired/stimulus';

type Theme = 'auto' | 'light' | 'dark';

export default class extends Controller<HTMLElement> {
  static readonly targets = ['btnToggle', 'btnOn', 'btnOff', 'btnAuto'];

  static readonly values = {
    dark: { type: String, default: 'Dark mode' },
    light: { type: String, default: 'Light mode' },
  };

  declare readonly btnOnTarget: HTMLButtonElement;
  declare readonly btnOffTarget: HTMLButtonElement;
  declare readonly btnAutoTarget: HTMLButtonElement;

  declare readonly darkValue: string;
  declare readonly lightValue: string;

  readonly darkThemeColor = '#1e1b4b';
  readonly lightThemeColor = '#a5b4fc';

  connect() {
    this.apply();

    this.prefersDarkScheme.addEventListener(
      'change',
      this.handleColorSchemeChange.bind(this),
    );

    document.addEventListener(
      'visibilitychange',
      this.handleVisibilityChange.bind(this),
    );
  }

  disconnect() {
    document.removeEventListener(
      'visibilitychange',
      this.handleVisibilityChange.bind(this),
    );

    this.prefersDarkScheme.removeEventListener(
      'change',
      this.handleColorSchemeChange.bind(this),
    );
  }

  handleColorSchemeChange() {
    if (this.theme === 'auto') this.apply();
  }

  handleVisibilityChange(): void {
    if (!document.hidden) {
      this.apply();
    }
  }

  on() {
    this.theme = 'dark';
    this.apply();
  }

  off() {
    this.theme = 'light';
    this.apply();
  }

  auto() {
    this.theme = 'auto';
    this.apply();
  }

  apply() {
    this.updateHtmlClass();
    this.updateMetaTag();
    this.updateButtons();
  }

  updateButtons() {
    this.btnOnTarget.classList.toggle('font-bold', this.theme === 'dark');
    this.btnOffTarget.classList.toggle('font-bold', this.theme === 'light');
    this.btnAutoTarget.classList.toggle('font-bold', this.theme === 'auto');
  }

  updateHtmlClass() {
    if (this.isCurrentlyDark) {
      document.documentElement.classList.add('dark');
    } else {
      document.documentElement.classList.remove('dark');
    }
  }

  updateMetaTag() {
    const color = this.isCurrentlyDark
      ? this.darkThemeColor
      : this.lightThemeColor;

    const themeMetaTag = document.querySelector('meta[name="theme-color"]');
    if (themeMetaTag) {
      themeMetaTag.setAttribute('content', color);
    }
  }

  get isCurrentlyDark(): boolean {
    return (
      this.theme === 'dark' ||
      (this.theme === 'auto' && this.prefersDarkScheme.matches)
    );
  }

  get theme(): Theme {
    if ('theme' in localStorage) {
      return localStorage.getItem('theme') === 'dark' ? 'dark' : 'light';
    }

    return 'auto';
  }

  get prefersDarkScheme(): MediaQueryList {
    return window.matchMedia('(prefers-color-scheme: dark)');
  }

  set theme(value: Theme) {
    if (value === 'auto') {
      localStorage.removeItem('theme');
      return;
    }

    localStorage.setItem('theme', value);
  }
}
