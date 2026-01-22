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
  private boundHandleVisibilityChange?: () => void;
  private boundHandleFocus?: () => void;
  private lastIsDark?: boolean;
  private ignoreMediaQueryChangesUntil: number = 0;

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

    this.boundHandleVisibilityChange = this.handleVisibilityChange.bind(this);
    document.addEventListener(
      'visibilitychange',
      this.boundHandleVisibilityChange,
    );

    this.boundHandleFocus = this.handleFocus.bind(this);
    window.addEventListener('focus', this.boundHandleFocus);
  }

  removeListeners() {
    if (this.boundHandleFocus)
      window.removeEventListener('focus', this.boundHandleFocus);

    if (this.boundHandleVisibilityChange)
      document.removeEventListener(
        'visibilitychange',
        this.boundHandleVisibilityChange,
      );

    if (this.boundHandleColorSchemeChange)
      this.prefersDarkScheme.removeEventListener(
        'change',
        this.boundHandleColorSchemeChange,
      );
  }

  handleColorSchemeChange() {
    // On iOS, resuming from background can fire change events with incorrect values.
    // Ignore media query changes briefly after resume to prevent theme flash.
    if (Date.now() < this.ignoreMediaQueryChangesUntil) return;

    if (this.theme === 'auto') {
      this.apply();
    }
  }

  handleFocus() {
    // On iOS, resuming from background can cause the DOM state to be inconsistent.
    // Immediately restore the theme based on our last known state, and block
    // media query change events briefly to prevent flash from incorrect values.
    this.ignoreMediaQueryChangesUntil = Date.now() + 1000;
    this.restoreThemeIfNeeded();
  }

  handleVisibilityChange() {
    if (document.hidden) return;

    // On iOS, resuming from background can cause the DOM state to be inconsistent.
    // Immediately restore the theme based on our last known state, and block
    // media query change events briefly to prevent flash from incorrect values.
    this.ignoreMediaQueryChangesUntil = Date.now() + 1000;
    this.restoreThemeIfNeeded();
  }

  private restoreThemeIfNeeded() {
    // Only restore for 'auto' theme - explicit light/dark don't need restoration
    if (this.theme !== 'auto' || this.lastIsDark === undefined) return;

    // Check if HTML class matches our last known state
    const htmlIsDark = document.documentElement.classList.contains('dark');
    if (htmlIsDark !== this.lastIsDark) {
      this.updateHtmlClass(this.lastIsDark);
      this.updateMetaTag(this.lastIsDark);
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

    // Always update lastIsDark so focus/visibility handlers have a reliable reference
    const previousIsDark = this.lastIsDark;
    this.lastIsDark = isDark;

    // Only broadcast if there was an actual change
    if (previousIsDark !== isDark) {
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
