import { Controller } from '@hotwired/stimulus';
import { readCookie, writeCookie } from '@/utils/cookie';

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

  private boundHandleColorSchemeChange?: () => void;
  private boundHandleMorph?: () => void;
  private lastIsDark?: boolean;
  private colorSchemeChangeTimeout?: ReturnType<typeof setTimeout>;

  connect() {
    this.apply();
    this.addListeners();
  }

  disconnect() {
    clearTimeout(this.colorSchemeChangeTimeout);
    this.removeListeners();
  }

  addListeners() {
    this.boundHandleColorSchemeChange = this.handleColorSchemeChange.bind(this);
    this.prefersDarkScheme.addEventListener(
      'change',
      this.boundHandleColorSchemeChange,
    );

    this.boundHandleMorph = this.apply.bind(this);
    document.addEventListener('turbo:morph', this.boundHandleMorph);
  }

  removeListeners() {
    if (this.boundHandleColorSchemeChange)
      this.prefersDarkScheme.removeEventListener(
        'change',
        this.boundHandleColorSchemeChange,
      );

    if (this.boundHandleMorph)
      document.removeEventListener('turbo:morph', this.boundHandleMorph);
  }

  handleColorSchemeChange() {
    if (this.theme !== 'auto') return;

    // Debounce to filter out bogus iOS resume events.
    // iOS can fire change events with incorrect values when resuming,
    // but typically corrects itself shortly after.
    clearTimeout(this.colorSchemeChangeTimeout);
    this.colorSchemeChangeTimeout = setTimeout(() => {
      this.apply();
    }, 200);
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
    this.updateMetaTag();
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

  // Read the color the page actually paints instead of keeping a second copy
  // of it here. updateHtmlClass runs first, so --color-chrome already resolves
  // to the value of the new theme.
  updateMetaTag() {
    const color = getComputedStyle(document.documentElement)
      .getPropertyValue('--color-chrome')
      .trim();

    // No stylesheet yet. The server rendered the correct color, so leave it.
    if (!color) return;

    // :not([media]) matters. The server puts the prefers-color-scheme variant
    // first, so a plain query would return that one and leave the fallback
    // below it untouched.
    const themeMetaTag = document.querySelector(
      'meta[name="theme-color"]:not([media])',
    );
    if (themeMetaTag) {
      themeMetaTag.setAttribute('content', color);
    }

    // While the visitor follows the system, the variant is the right answer
    // and stays. It only goes once they picked a theme, because it would then
    // override that choice. Never before the line above: dropping it first
    // lets the untouched fallback show the wrong color for one frame, which
    // is what made the toolbar color flicker between reloads.
    if (this.theme === 'auto') return;

    for (const variant of document.querySelectorAll(
      'meta[name="theme-color"][media]',
    )) {
      variant.remove();
    }
  }

  get isCurrentlyDark(): boolean {
    return (
      this.theme === 'dark' ||
      (this.theme === 'auto' && this.prefersDarkScheme.matches)
    );
  }

  get theme(): Theme {
    const stored = readCookie('theme');
    if (stored === 'dark' || stored === 'light') {
      return stored;
    }

    return 'auto';
  }

  set theme(value: Theme) {
    writeCookie('theme', value === 'auto' ? null : value);
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
