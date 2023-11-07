import { Controller } from '@hotwired/stimulus';
import { enter, leave } from 'el-transition';

export default class extends Controller<HTMLElement> {
  connect() {
    enter(this.element).then(() => {
      setTimeout(() => {
        this.remove();
      }, 2000);
    });
  }

  remove() {
    leave(this.element).then(() => {
      this.element.remove();
    });
  }
}
