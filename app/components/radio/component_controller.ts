import { Controller } from '@hotwired/stimulus';
import * as Turbo from '@hotwired/turbo';

interface Dim {
  value: string;
  width: number;
  left: number;
}

export default class extends Controller {
  static readonly targets = ['highlight', 'choice'];
  static readonly values = {
    url: String,
    cookieName: String,
  };

  declare readonly highlightTarget: HTMLElement;
  declare readonly choiceTargets: HTMLElement[];
  declare readonly urlValue: string;
  declare readonly cookieNameValue: string;

  private dims: Dim[] = [];
  private selectedValue: string | undefined;

  connect(): void {
    this.selectedValue =
      this.getCookie() ?? this.choiceTargets[0].querySelector('input')!.value;

    this.calculateDims();

    // Initial rendering without animation
    this.highlightTarget.style.transition = 'none';
    this.moveHighlight();
    // force reflow, so the browser handles it without animation
    this.highlightTarget.getBoundingClientRect();
    // Re-enable transition
    this.highlightTarget.style.transition = '';

    window.addEventListener('resize', this.handleResize.bind(this));
  }

  disconnect(): void {
    window.removeEventListener('resize', this.handleResize.bind(this));
  }

  select(event: Event): void {
    const input = event.currentTarget as HTMLInputElement;
    this.selectedValue = input.value;

    this.setCookie();
    this.moveHighlight();
    Turbo.visit(this.urlValue);
  }

  private handleResize(): void {
    this.calculateDims();
    this.moveHighlight();
  }

  private calculateDims(): void {
    this.dims = this.choiceTargets.map((el) => {
      const input = el.querySelector('input') as HTMLInputElement;

      return {
        value: input.value,
        width: el.offsetWidth,
        left: el.offsetLeft,
      };
    });
  }

  private moveHighlight(): void {
    const dim = this.dims.find((d) => d.value === this.selectedValue);
    if (!dim) return;

    this.highlightTarget.style.width = `${dim.width}px`;
    this.highlightTarget.style.transform = `translateX(${dim.left}px)`;
  }

  private setCookie(): void {
    if (this.selectedValue)
      document.cookie = [
        `${this.cookieNameValue}=${encodeURIComponent(this.selectedValue)}`,
        'path=/',
      ].join('; ');
  }

  private getCookie(): string | undefined {
    const cookie = document.cookie
      .split('; ')
      .find((c) => c.startsWith(`${this.cookieNameValue}=`));
    if (!cookie) return;

    return decodeURIComponent(cookie.split('=')[1]);
  }
}
