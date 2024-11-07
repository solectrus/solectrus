import { Controller } from '@hotwired/stimulus';
import * as Turbo from '@hotwired/turbo';

export default class extends Controller {
  static readonly targets = ['timeEstimate', 'remaining'];

  declare readonly timeEstimateTarget: HTMLElement;
  declare readonly remainingTarget: HTMLElement;
  declare readonly hasTimeEstimateTarget: boolean;

  static readonly values = {
    reloadOnComplete: {
      type: Boolean,
      default: false,
    },
    minutesOne: { type: String, default: '' },
    minutesOther: { type: String, default: '' },
    secondsOne: { type: String, default: '' },
    secondsOther: { type: String, default: '' },
  };

  declare readonly reloadOnCompleteValue: boolean;
  declare readonly minutesOneValue: string;
  declare readonly minutesOtherValue: string;
  declare readonly secondsOneValue: string;
  declare readonly secondsOtherValue: string;

  startTime: number = 0;
  private frameCache: Turbo.FrameElement[] | null = null;

  connect() {
    this.startTime = Date.now();
    this.loadNextFrame(0);
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

    if (frame) {
      // Load the next frame and prepare to load the following one
      frame.addEventListener(
        'turbo:frame-load',
        () => this.loadNextFrame(index + 1),
        { once: true },
      );
      frame.src = frame.dataset.src;

      this.updateTimeEstimate(index);
    } else {
      // All frames have been loaded, reload the page
      if (this.reloadOnCompleteValue) {
        Turbo.visit(window.location.href, { action: 'replace' });
      }
    }
  }

  updateTimeEstimate(index: number) {
    // Skip if the time estimate is not enabled
    if (!this.hasTimeEstimateTarget) return;

    // Avoid showing the remaining time estimate until we have enough data
    if (index < 3) return;

    // Calculate the estimated remaining time and render it
    const estimatedRemainingSeconds = this.estimateRemainingTimeSeconds(index);
    this.renderRemainingTime(estimatedRemainingSeconds);
  }

  renderRemainingTime(estimatedRemainingSeconds: number) {
    if (estimatedRemainingSeconds === 0) {
      // Avoid "0 seconds remaining" message
      this.hideTimeEstimate();
      return;
    }

    if (estimatedRemainingSeconds > 60) {
      // Show remaining time in minutes
      const estimatedMinutes = Math.ceil(estimatedRemainingSeconds / 60);
      const minutesText =
        estimatedMinutes === 1
          ? this.minutesOneValue
          : this.minutesOtherValue.replace(
              '%{count}',
              estimatedMinutes.toString(),
            );
      this.remainingTarget.textContent = minutesText;
    } else {
      // Show remaining time in seconds
      const estimatedSeconds = Math.ceil(estimatedRemainingSeconds);
      const secondsText =
        estimatedSeconds === 1
          ? this.secondsOneValue
          : this.secondsOtherValue.replace(
              '%{count}',
              estimatedSeconds.toString(),
            );
      this.remainingTarget.textContent = secondsText;
    }

    this.showTimeEstimate();
  }

  // Calculate the average time per frame and estimate remaining time
  estimateRemainingTimeSeconds(index: number) {
    const elapsedTime = Date.now() - this.startTime;
    const averageTimePerFrame = elapsedTime / (index + 1);
    const remainingFrames = this.frameElements.length - (index + 1);
    const estimatedRemainingSeconds = Math.ceil(
      (remainingFrames * averageTimePerFrame) / 1000,
    );

    return estimatedRemainingSeconds;
  }

  showTimeEstimate() {
    this.timeEstimateTarget.classList.remove('invisible');
  }

  hideTimeEstimate() {
    this.timeEstimateTarget.classList.add('invisible');
  }
}
