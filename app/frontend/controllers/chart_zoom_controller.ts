import { Controller } from '@hotwired/stimulus';
import type { FrameElement } from '@hotwired/turbo';

export default class extends Controller {
  static readonly targets = ['expandBtn', 'closeBtn', 'insightsBtn', 'loading'];
  static readonly values = { zoomInterval: String };

  declare readonly expandBtnTarget: HTMLElement;
  declare readonly closeBtnTarget: HTMLElement;
  declare readonly insightsBtnTarget: HTMLElement;
  declare readonly loadingTarget: HTMLElement;

  declare readonly zoomIntervalValue: string;
  declare readonly hasZoomIntervalValue: boolean;

  private loadingTimeout?: ReturnType<typeof setTimeout>;

  connect() {
    // Clean up transition-stopper left over from zoom close
    document.body.classList.remove('transition-stopper');

    // After turbo frame reload in zoom mode: set up keyboard + resize
    if (document.body.classList.contains('chart-zoom-active')) {
      this.setupKeyboardHandler();
      window.dispatchEvent(new Event('resize'));
    }
  }

  expand() {
    this.dismissTooltip();
    this.showLoadingOverlay();
    this.setZoomState(true);
    this.setupKeyboardHandler();

    if (this.hasZoomIntervalValue) {
      this.reloadFrame(this.zoomIntervalValue);
    } else {
      window.dispatchEvent(new Event('resize'));
      this.hideLoadingAfterResize();
    }
  }

  close() {
    this.removeKeyboardHandler();

    if (this.hasZoomIntervalValue) {
      this.showLoadingOverlay();
      document.body.classList.add('transition-stopper');
      this.setZoomState(false);
      this.reloadFrame();
      return;
    }

    this.setZoomState(false);
    window.dispatchEvent(new Event('resize'));
  }

  disconnect() {
    this.removeKeyboardHandler();
    if (this.loadingTimeout) clearTimeout(this.loadingTimeout);
  }

  private setZoomState(active: boolean) {
    const action = active ? 'add' : 'remove';
    document.body.classList[action]('chart-zoom-active');
    this.element.classList[action]('chart-zoomed');
    this.markFrame(action);
  }

  private setupKeyboardHandler() {
    document.addEventListener('keydown', this.handleKeydown);
  }

  private removeKeyboardHandler() {
    document.removeEventListener('keydown', this.handleKeydown);
  }

  private markFrame(action: 'add' | 'remove') {
    const frame = this.element.closest('turbo-frame');
    if (frame) frame.classList[action]('chart-zoom-frame');
  }

  private dismissTooltip() {
    this.expandBtnTarget.dispatchEvent(
      new PointerEvent('pointerleave', { pointerType: 'mouse' }),
    );
  }

  private showLoadingOverlay() {
    this.loadingTarget.classList.remove('hidden');

    // Restart SVG SMIL animations (paused while display:none)
    this.loadingTarget
      .querySelectorAll('animate')
      .forEach((anim) => anim.beginElement());
  }

  private hideLoadingAfterResize() {
    // Resize handler is debounced (100ms) + synchronous chart rebuild
    this.loadingTimeout = setTimeout(() => {
      this.loadingTarget.classList.add('hidden');
    }, 250);
  }

  private reloadFrame(interval?: string) {
    const frame = this.element.closest('turbo-frame') as FrameElement | null;
    if (!frame?.src) return;

    const url = new URL(frame.src, window.location.origin);
    if (interval) {
      url.searchParams.set('interval', interval);
    } else {
      url.searchParams.delete('interval');
    }
    frame.src = url.toString();
  }

  private readonly handleKeydown = (event: KeyboardEvent): void => {
    if (event.key === 'Escape') this.close();
  };
}
