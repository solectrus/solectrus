import { Controller } from '@hotwired/stimulus';
import { enter, leave } from 'el-transition';

export default class extends Controller<HTMLElement> {
  private removeTimeout?: ReturnType<typeof setTimeout>;

  connect() {
    enter(this.element).then(() => {
      this.removeTimeout = setTimeout(() => {
        this.remove();
      }, 2000);
    });
  }

  disconnect() {
    if (this.removeTimeout) {
      clearTimeout(this.removeTimeout);
      this.removeTimeout = undefined;
    }
  }

  remove() {
    leave(this.element).then(() => {
      this.element.remove();
    });
  }
}
