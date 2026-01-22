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

  private boundHandleColorSchemeChange?: () => void;
  private lastIsDark?: boolean;

  connect() {
    this.apply();
    this.addListeners();
  }

  disconnect() {
    this.removeListeners();
  }

  addListeners() {
    this.boundHandleColorSchemeChange = this.handleColorSchemeChange.bind(this);
    this.prefersDarkScheme.addEventListener(
      'change',
      this.boundHandleColorSchemeChange,
    );
  }

  removeListeners() {
    if (this.boundHandleColorSchemeChange)
      this.prefersDarkScheme.removeEventListener(
        'change',
        this.boundHandleColorSchemeChange,
      );
  }

  handleColorSchemeChange() {
    // Ignore bogus change events fired by iOS when resuming from background
    if (document.hidden) return;

    if (this.theme === 'auto') {
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
    const isDark = this.isCurrentlyDark;
    this.updateHtmlClass(isDark);
    this.updateMetaTag(isDark);
    this.updateButtons();

    // Only broadcast if there was an actual change
    if (this.lastIsDark !== isDark) {
      this.lastIsDark = isDark;
      document.dispatchEvent(
        new CustomEvent('theme:changed', {
          detail: { dark: isDark },
        }),
      );
    }
  }

  updateButtons() {
    for (const input of this.inputDarkTargets) {
      input.checked = this.theme === 'dark';
    }

    for (const input of this.inputLightTargets) {
      input.checked = this.theme === 'light';
    }

    for (const input of this.inputAutoTargets) {
      input.checked = this.theme === 'auto';
    }
  }

  updateHtmlClass(isDark: boolean) {
    document.documentElement.classList.toggle('dark', isDark);
  }

  updateMetaTag(isDark: boolean) {
    const color = isDark ? this.darkThemeColor : this.lightThemeColor;

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
    const storedTheme = localStorage.getItem('theme');
    if (storedTheme === 'dark' || storedTheme === 'light') {
      return storedTheme;
    }

    return 'auto';
  }

  set theme(value: Theme) {
    if (value === 'auto') {
      localStorage.removeItem('theme');
      return;
    }

    localStorage.setItem('theme', value);
  }

  get prefersDarkScheme(): MediaQueryList {
    return window.matchMedia
      ? window.matchMedia('(prefers-color-scheme: dark)')
      : ({
          matches: false,
          addEventListener: () => {},
          removeEventListener: () => {},
        } as unknown as MediaQueryList);
  }
}
