import { Controller } from '@hotwired/stimulus';

export default class extends Controller {
  static targets = ['btnOn', 'btnOff'];

  declare readonly btnOnTargets: HTMLElement[];
  declare readonly btnOffTargets: HTMLElement[];

  connect() {
    this.updateButtons();

    if (this.isFullscreenSupported())
      document.addEventListener(
        'fullscreenchange',
        this.fullscreenChangeListener.bind(this),
      );
  }

  disconnect() {
    if (this.isFullscreenSupported())
      document.removeEventListener(
        'fullscreenchange',
        this.fullscreenChangeListener.bind(this),
      );
  }

  fullscreenChangeListener() {
    this.updateButtons();
  }

  isFullscreenSupported() {
    return !!document.documentElement.requestFullscreen;
  }

  on() {
    if (!document.fullscreenElement) {
      document.documentElement.requestFullscreen();
    }
  }

  off() {
    if (document.fullscreenElement) {
      document.exitFullscreen();
    }
  }

  updateButtons() {
    const showOnButton =
      !document.fullscreenElement && this.isFullscreenSupported();
    const showOffButton =
      document.fullscreenElement && this.isFullscreenSupported();

    this.btnOnTargets.forEach((btn) =>
      btn.classList.toggle('hidden', !showOnButton),
    );
    this.btnOffTargets.forEach((btn) =>
      btn.classList.toggle('hidden', !showOffButton),
    );
  }
}
