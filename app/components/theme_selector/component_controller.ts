import { Controller } from '@hotwired/stimulus';

type Theme = 'auto' | 'light' | 'dark';

export default class extends Controller<HTMLElement> {
  static readonly targets = ['btnToggle', 'btnOn', 'btnOff', 'btnAuto'];

  static readonly values = {
    dark: { type: String, default: 'Dark mode' },
    light: { type: String, default: 'Light mode' },
  };

  declare readonly btnOnTargets: HTMLButtonElement[];
  declare readonly btnOffTargets: HTMLButtonElement[];
  declare readonly btnAutoTargets: HTMLButtonElement[];

  declare readonly darkValue: string;
  declare readonly lightValue: string;

  readonly darkThemeColor = '#1e1b4b';
  readonly lightThemeColor = '#a5b4fc';

  connect() {
    this.apply();
    this.addListeners();
  }

  disconnect() {
    this.removeListeners();
  }

  addListeners() {
    this.prefersDarkScheme.addEventListener(
      'change',
      this.handleColorSchemeChange.bind(this),
    );

    document.addEventListener(
      'visibilitychange',
      this.handleVisibilityChange.bind(this),
    );
  }

  removeListeners() {
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
    if (this.theme === 'auto') {
      this.apply();
    }
  }

  handleVisibilityChange() {
    if (!document.hidden && this.theme === 'auto') {
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
    this.btnOnTargets.forEach((btn) => {
      btn.classList.toggle('font-bold', this.theme === 'dark');
    });

    this.btnOffTargets.forEach((btn) => {
      btn.classList.toggle('font-bold', this.theme === 'light');
    });

    this.btnAutoTargets.forEach((btn) => {
      btn.classList.toggle('font-bold', this.theme === 'auto');
    });
  }

  updateHtmlClass() {
    document.documentElement.classList.toggle('dark', this.isCurrentlyDark);
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
