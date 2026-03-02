import { Controller } from '@hotwired/stimulus';
import type { FrameElement } from '@hotwired/turbo';

export default class extends Controller {
  static readonly targets = ['maximizeBtn', 'loading'];
  static readonly values = { zoomInterval: String };

  declare readonly maximizeBtnTarget: HTMLElement;
  declare readonly loadingTarget: HTMLElement;

  declare readonly zoomIntervalValue: string;
  declare readonly hasZoomIntervalValue: boolean;

  connect() {
    // After turbo frame reload in zoom mode: restore zoom state + keyboard + resize
    if (!document.body.classList.contains('chart-zoom-active')) return;

    this.markFrame('add');
    this.setKeyboardHandler(true);
    this.triggerResize();
  }

  maximize() {
    this.dismissTooltip();
    this.toggleZoom(true);
  }

  minimize() {
    this.toggleZoom(false);
  }

  disconnect() {
    this.setKeyboardHandler(false);

    requestAnimationFrame(() => {
      if (document.querySelector('turbo-frame[data-zoomed]')) return;

      document.body.classList.remove('chart-zoom-active');
    });
  }

  private setZoomState(active: boolean) {
    const action = active ? 'add' : 'remove';
    document.body.classList[action]('chart-zoom-active');
    this.markFrame(action);
    this.setKeyboardHandler(active);
  }

  private toggleZoom(active: boolean) {
    this.setZoomState(active);

    if (this.hasZoomIntervalValue && this.zoomIntervalValue) {
      this.showLoadingOverlay();
      this.reloadFrame(active ? this.zoomIntervalValue : undefined);
      return;
    }

    this.resizeWithOverlay();
  }

  private get frame(): FrameElement | null {
    return this.element.closest('turbo-frame') as FrameElement | null;
  }

  private markFrame(action: 'add' | 'remove') {
    const frame = this.frame;
    if (!frame) return;

    if (action === 'add') {
      frame.setAttribute('data-zoomed', '');
      frame.classList.add('group/zoom');
    } else {
      frame.removeAttribute('data-zoomed');
      frame.classList.remove('group/zoom');
    }
  }

  private setKeyboardHandler(active: boolean) {
    if (active) document.addEventListener('keydown', this.handleKeydown);
    else document.removeEventListener('keydown', this.handleKeydown);
  }

  private dismissTooltip() {
    this.maximizeBtnTarget.dispatchEvent(
      new PointerEvent('pointerleave', { pointerType: 'mouse' }),
    );
  }

  private showLoadingOverlay() {
    this.loadingTarget.classList.remove('invisible');
  }

  private resizeWithOverlay() {
    this.showLoadingOverlay();
    this.triggerResize();
    requestAnimationFrame(() =>
      requestAnimationFrame(() =>
        this.loadingTarget.classList.add('invisible'),
      ),
    );
  }

  private triggerResize() {
    window.dispatchEvent(new Event('resize'));
  }

  private reloadFrame(interval?: string) {
    const frame = this.frame;
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
    if (event.key === 'Escape') this.minimize();
  };
}
