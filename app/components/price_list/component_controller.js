import { Controller } from '@hotwired/stimulus';

export default class extends Controller {
  static targets = ['adminOnly'];

  connect() {
    if (!this.isAdmin)
      this.adminOnlyTargets.forEach((element) => {
        element.remove();
      });
  }

  get isAdmin() {
    return this.cookieExists('admin');
  }

  cookieExists(name) {
    let cks = document.cookie.split(';');
    for (let i = 0; i < cks.length; i++)
      if (cks[i].split('=')[0].trim() == name) return true;
  }
}
