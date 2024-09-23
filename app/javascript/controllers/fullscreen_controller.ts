import { Controller } from '@hotwired/stimulus';

export default class extends Controller {
  static readonly targets = ['btnOn', 'btnOff'];

  declare readonly btnOnTargets: HTMLElement[];
  declare readonly btnOffTargets: HTMLElement[];

  private boundFullscreenChangeListener?: () => void;

  connect() {
    this.updateButtons();

    if (this.isFullscreenSupported()) {
      this.boundFullscreenChangeListener =
        this.fullscreenChangeListener.bind(this);

      document.addEventListener(
        'fullscreenchange',
        this.boundFullscreenChangeListener,
      );
    }
  }

  disconnect() {
    if (this.boundFullscreenChangeListener)
      document.removeEventListener(
        'fullscreenchange',
        this.boundFullscreenChangeListener,
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
