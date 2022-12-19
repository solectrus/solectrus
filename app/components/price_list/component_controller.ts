import { Controller } from '@hotwired/stimulus';

export default class extends Controller {
  static targets = ['adminOnly'];

  declare readonly hasAdminOnlyTarget: boolean;
  declare readonly adminOnlyTarget: HTMLElement;
  declare readonly adminOnlyTargets: HTMLElement[];

  connect() {
    if (!this.isAdmin)
      this.adminOnlyTargets.forEach((element) => {
        element.remove();
      });
  }

  get isAdmin() {
    return this.cookieExists('admin');
  }

  cookieExists(name: string) {
    const cks = document.cookie.split(';');
    for (let i = 0; i < cks.length; i++)
      if (cks[i].split('=')[0].trim() == name) return true;
  }
}
