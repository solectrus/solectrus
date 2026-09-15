import { Controller } from '@hotwired/stimulus';

// Removes turbo-permanent attributes before navigation to ensure frames are refreshed
export default class extends Controller {
  perform() {
    // Frames only. The ThemeStrip and the theme-color meta tags are permanent
    // too, but they are not content: they carry the color the browser paints
    // its toolbar with, and Safari holds on to the element it read that color
    // from. See components/theme_strip/component.rb.
    document
      .querySelectorAll('turbo-frame[data-turbo-permanent]')
      .forEach((el) => el.removeAttribute('data-turbo-permanent'));
  }
}
