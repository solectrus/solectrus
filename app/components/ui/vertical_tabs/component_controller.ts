import { Controller } from '@hotwired/stimulus';

// Shows the panel of the selected tab (see Ui::VerticalTabs::Component). At
// the start, the hash of the address can name the panel.
export default class extends Controller {
  static readonly targets = ['tab', 'panel'];

  declare readonly tabTargets: HTMLElement[];
  declare readonly panelTargets: HTMLElement[];

  connect() {
    const id = window.location.hash.slice(1);
    if (id) this.activate(this.panelTargets.findIndex((it) => it.id === id));
  }

  select(event: Event) {
    event.preventDefault();
    this.activate(this.tabTargets.indexOf(event.currentTarget as HTMLElement));
  }

  private activate(index: number) {
    if (index < 0) return;

    this.tabTargets.forEach((tab, i) =>
      tab.setAttribute('aria-selected', String(i === index)),
    );
    this.panelTargets.forEach((panel, i) => (panel.hidden = i !== index));
  }
}
