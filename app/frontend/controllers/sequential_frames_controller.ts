import { Controller } from '@hotwired/stimulus';
import * as Turbo from '@hotwired/turbo';
import { appLocale } from '@/utils/locale';

// A guess for the days of the first frame, before their pace is known
const FIRST_DAY_MS = 150;
const FINAL_MS = 250;

// Loads the frames of the Summary::Builder one after the other. Each frame
// builds a chunk of days, and the bar, the percentage and the time left follow
// the days already built. The page loads again when the last frame is done.
export default class extends Controller {
  static readonly targets = ['bar', 'fill', 'percent', 'remaining'];

  declare readonly barTarget: HTMLElement;
  declare readonly fillTarget: HTMLElement;
  declare readonly percentTarget: HTMLElement;
  declare readonly remainingTarget: HTMLElement;
  declare readonly hasPercentTarget: boolean;

  static readonly values = {
    reloadOnComplete: {
      type: Boolean,
      default: false,
    },
    total: { type: Number, default: 0 },
    texts: { type: Object, default: {} },
  };

  declare readonly reloadOnCompleteValue: boolean;
  declare readonly totalValue: number;
  declare readonly textsValue: Record<
    'less_than_a_minute' | 'minute' | 'minutes' | 'hours',
    string
  >;

  private startTime = 0;
  private done = 0;
  private shownSeconds = Infinity;
  private frameCache: Turbo.FrameElement[] | null = null;
  private readonly percentFormat = new Intl.NumberFormat(appLocale(), {
    style: 'percent',
  });

  connect() {
    this.startTime = Date.now();
    this.done = 0;
    this.shownSeconds = Infinity;
    this.showProgress();
    this.loadNextFrame(0);
  }

  disconnect() {
    // Clear the cached frame elements to prevent holding DOM references
    this.frameCache = null;
  }

  get frameElements(): Turbo.FrameElement[] {
    if (this.frameCache === null) {
      this.frameCache = Array.from(
        this.element.querySelectorAll('turbo-frame[data-src]'),
      );
    }
    return this.frameCache;
  }

  loadNextFrame(index: number) {
    const frame = this.frameElements[index];
    if (!frame) return this.complete();

    const days = Number(frame.dataset.days);

    // Load the frame, then the one after it
    frame.addEventListener(
      'turbo:frame-load',
      () => {
        this.done += days;
        this.showProgress();
        this.loadNextFrame(index + 1);
      },
      { once: true },
    );
    this.retryOnError(frame);
    frame.src = frame.dataset.src;

    // While the frame builds, the bar moves on at the pace of the days before,
    // but only to 90 % of the step of the frame. So it moves without stops,
    // even with a single frame, and it does not run ahead of the days built.
    const pace = this.done
      ? (Date.now() - this.startTime) / this.done
      : FIRST_DAY_MS;
    this.glide((this.done + days * 0.9) / this.totalValue, days * pace);
  }

  // The bar runs to its end before the page loads again
  async complete() {
    this.glide(1, FINAL_MS);
    await Promise.allSettled(
      this.fillTarget.getAnimations().map((animation) => animation.finished),
    );

    if (this.reloadOnCompleteValue)
      Turbo.visit(window.location.href, { action: 'replace' });
  }

  // A frame request can fail when connectivity is briefly unavailable (e.g.
  // right after the device booted). Without this the sequence would stall on
  // the loading spinner forever. Retry the frame until it succeeds.
  retryOnError(frame: Turbo.FrameElement) {
    frame.addEventListener(
      'turbo:fetch-request-error',
      () => {
        this.retryOnError(frame);
        setTimeout(() => frame.reload(), 2000);
      },
      { once: true },
    );
  }

  glide(share: number, ms: number) {
    this.fillTarget.style.transitionDuration = `${ms}ms`;
    this.fillTarget.style.translate = `${(share - 1) * 100}% 0`;
  }

  // Rounded down, so the page shows 100 % only when it is done. A single frame
  // has no figures below the bar.
  showProgress() {
    const share = this.done / this.totalValue;
    const percent = Math.floor(share * 100);
    this.barTarget.setAttribute('aria-valuenow', String(percent));
    if (!this.hasPercentTarget) return;

    this.percentTarget.textContent = this.percentFormat.format(percent / 100);
    if (this.done)
      this.showRemaining(
        ((Date.now() - this.startTime) * (1 / share - 1)) / 1000,
      );
  }

  // The days of one frame take more or less time than the days before, so
  // the estimate goes up only with a clear change. Otherwise it would go up
  // and down from frame to frame.
  showRemaining(seconds: number) {
    if (seconds > this.shownSeconds && seconds < this.shownSeconds * 1.25)
      seconds = this.shownSeconds;
    this.shownSeconds = seconds;

    this.remainingTarget.textContent = this.remainingText(seconds);
  }

  remainingText(seconds: number) {
    const texts = this.textsValue;
    if (seconds <= 0) return '';
    if (seconds < 45) return texts.less_than_a_minute;

    const minutes = Math.round(seconds / 60);
    if (minutes === 1) return texts.minute;
    if (minutes < 120)
      return texts.minutes.replace('%{count}', String(minutes));

    return texts.hours.replace('%{count}', String(Math.round(minutes / 60)));
  }
}
