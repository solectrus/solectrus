import { Controller } from '@hotwired/stimulus';

export default class extends Controller {
  static readonly targets = ['tab', 'panel'];
  static readonly values = {
    activeTab: String,
    inactiveTab: String,
    activePanel: String,
    hiddenPanel: String,
  };

  declare tabTargets: HTMLElement[];
  declare panelTargets: HTMLElement[];

  declare readonly activeTabValue: string;
  declare readonly inactiveTabValue: string;
  declare readonly activePanelValue: string;
  declare readonly hiddenPanelValue: string;

  connect() {
    const hash = window.location.hash?.replace('#', '');
    let panelIndex = 0;

    if (hash) {
      const foundIndex = this.panelTargets.findIndex(
        (panel) => panel.id === hash,
      );
      if (foundIndex >= 0) panelIndex = foundIndex;
    }

    this.activate(this.tabTargets[panelIndex], this.panelTargets[panelIndex]);
  }

  select(event: Event) {
    event.preventDefault();

    const tab = event.currentTarget as HTMLElement;
    const index = this.tabTargets.indexOf(tab);
    const panel = this.panelTargets[index];

    if (tab && panel) {
      this.activate(tab, panel);
      history.replaceState(null, '', `#${panel.id}`); // No scroll
    }
  }

  activate(tab?: HTMLElement, panel?: HTMLElement) {
    if (!tab || !panel) return;

    this.tabTargets.forEach((el) => {
      el.classList.remove(...this.activeTabValue.split(' '));
      el.classList.add(...this.inactiveTabValue.split(' '));
    });

    this.panelTargets.forEach((el) => {
      el.classList.remove(...this.activePanelValue.split(' '));
      el.classList.add(...this.hiddenPanelValue.split(' '));
    });

    tab.classList.remove(...this.inactiveTabValue.split(' '));
    tab.classList.add(...this.activeTabValue.split(' '));

    panel.classList.remove(...this.hiddenPanelValue.split(' '));
    panel.classList.add(...this.activePanelValue.split(' '));
  }
}
