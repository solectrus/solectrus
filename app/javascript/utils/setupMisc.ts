// Lock screen orientation to portrait on small devices.
// Allow landscape on `lg` or larger.
if ('orientation' in screen) {
  window.addEventListener('resize', () => {
    if (window.innerWidth < 1024)
      screen.orientation.lock('portrait').catch(() => {
        /* noop */
      });
    else screen.orientation.unlock();
  });
}
