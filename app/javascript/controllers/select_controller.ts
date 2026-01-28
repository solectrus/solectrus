import { Controller } from '@hotwired/stimulus';
import * as Turbo from '@hotwired/turbo';

export default class extends Controller<HTMLSelectElement> {
  static readonly targets = ['select', 'temp'];

  declare readonly selectTarget: HTMLSelectElement;
  declare readonly tempTarget: HTMLSelectElement;

  connect() {
    this.autoWidth();
  }

  onChange() {
    const option = this.selectTarget.selectedOptions[0];
    if (!option) return;

    const url = option.value;
    if (!url) return;

    // Trigger any Stimulus actions declared on the option (e.g., stats-with-chart startLoop)
    option.dispatchEvent(new Event('click', { bubbles: true }));
    if (this.isChartOption(option)) {
      this.triggerChartSelect(option);
      return;
    }

    // Build options object only with defined values to avoid Turbo errors
    const visitOptions: { frame?: string; action?: 'replace' | 'advance' } = {};
    if (option.dataset.turboFrame) {
      visitOptions.frame = option.dataset.turboFrame;
    }
    if (
      option.dataset.turboAction === 'replace' ||
      option.dataset.turboAction === 'advance'
    ) {
      visitOptions.action = option.dataset.turboAction;
    }

    Turbo.visit(url, visitOptions);
  }

  autoWidth() {
    this.selectTarget.style.width = `${this.widthOfSelectedOption}px`;
  }

  private isChartOption(option: HTMLOptionElement) {
    return option.dataset.action?.includes(
      'stats-with-chart--component#loadChart',
    );
  }

  private triggerChartSelect(option: HTMLOptionElement) {
    this.statsController()?.loadChartForUrl?.(
      option.value,
      option.dataset.statsWithChartComponentChartUrlParam || undefined,
      option.dataset.statsWithChartComponentSensorNameParam || undefined,
    );
  }

  private statsController() {
    const statsElement = this.element.closest<HTMLElement>(
      '[data-controller~="stats-with-chart--component"]',
    );
    return statsElement
      ? (this.application.getControllerForElementAndIdentifier(
          statsElement,
          'stats-with-chart--component',
        ) as {
          loadChartForUrl?: (
            historyUrl: string,
            chartUrl?: string,
            sensorName?: string,
          ) => void;
        })
      : null;
  }

  // Hack to get the width of the selected option
  get widthOfSelectedOption() {
    // Get the text of the selected option
    const text =
      this.selectTarget.options[this.selectTarget.selectedIndex].text;

    // Use a temporary select which has just ONE option - the selected one
    this.tempTarget.innerHTML = `<option selected>${text}</option>`;

    // Return the width of the temporary select
    return this.tempTarget.clientWidth;
  }
}
