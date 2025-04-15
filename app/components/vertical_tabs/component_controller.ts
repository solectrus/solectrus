import { Controller } from '@hotwired/stimulus';

export default class extends Controller {
  static readonly targets = ['tab', 'panel', 'select'];
  static readonly values = {
    activeTab: String,
    inactiveTab: String,
    activePanel: String,
    hiddenPanel: String,
  };

  declare tabTargets: HTMLElement[];
  declare panelTargets: HTMLElement[];
  declare selectTarget: HTMLSelectElement;

  declare readonly activeTabValue: string;
  declare readonly inactiveTabValue: string;
  declare readonly activePanelValue: string;
  declare readonly hiddenPanelValue: string;

  declare readonly hasSelectTarget: boolean;

  connect() {
    this.activate(this.tabTargets[0], this.panelTargets[0]);
  }

  select(event: Event) {
    event.preventDefault();
    const tab = event.currentTarget as HTMLElement;
    const index = this.tabTargets.indexOf(tab);
    this.activate(tab, this.panelTargets[index]);
  }

  change() {
    const index = this.selectTarget.selectedIndex;
    const tab = this.tabTargets[index];
    const panel = this.panelTargets[index];
    this.activate(tab, panel);
  }

  activate(tab: HTMLElement, panel: HTMLElement) {
    this.tabTargets.forEach((el) => {
      el.className = this.inactiveTabValue;
    });

    this.panelTargets.forEach((el) => {
      el.classList.add(this.hiddenPanelValue);
      el.classList.remove(this.activePanelValue);
    });

    tab.className = this.activeTabValue;
    panel.classList.remove(this.hiddenPanelValue);
    panel.classList.add(this.activePanelValue);

    if (this.hasSelectTarget) {
      const index = this.tabTargets.indexOf(tab);
      this.selectTarget.selectedIndex = index;
    }
  }
}
