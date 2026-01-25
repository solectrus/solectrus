import { Controller } from '@hotwired/stimulus';

// Removes turbo-permanent attributes before navigation to ensure frames are refreshed
export default class extends Controller {
  perform() {
    // Remove turbo-permanent from all elements so they get replaced during navigation
    document
      .querySelectorAll('[data-turbo-permanent]')
      .forEach((el) => el.removeAttribute('data-turbo-permanent'));
  }
}
