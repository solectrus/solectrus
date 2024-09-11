import { Controller } from '@hotwired/stimulus';

type Theme = 'auto' | 'light' | 'dark';

export default class extends Controller<HTMLElement> {
  static readonly targets = ['inputDark', 'inputLight', 'inputAuto'];

  static readonly values = {
    dark: { type: String, default: 'Dark mode' },
    light: { type: String, default: 'Light mode' },
  };

  declare readonly inputDarkTargets: HTMLInputElement[];
  declare readonly inputLightTargets: HTMLInputElement[];
  declare readonly inputAutoTargets: HTMLInputElement[];

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

    document.addEventListener('focus', this.handleFocus.bind(this));
  }

  removeListeners() {
    document.removeEventListener('focus', this.handleFocus.bind(this));

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

  handleFocus() {
    this.apply();
  }

  handleVisibilityChange() {
    if (!document.hidden && this.theme === 'auto') {
      this.apply();
    }
  }

  dark() {
    this.theme = 'dark';
    this.apply();
  }

  light() {
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
    this.inputDarkTargets.forEach((input) => {
      input.checked = this.theme === 'dark';
    });

    this.inputLightTargets.forEach((input) => {
      input.checked = this.theme === 'light';
    });

    this.inputAutoTargets.forEach((input) => {
      input.checked = this.theme === 'auto';
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
