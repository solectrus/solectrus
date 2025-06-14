import { Controller } from '@hotwired/stimulus';
import { debounce, throttle } from 'throttle-debounce';

export default class extends Controller {
  static readonly values = { key: String };
  static readonly targets = ['scrollable', 'dot', 'btnPrev', 'btnNext'];

  declare keyValue: string;
  declare scrollableTarget: HTMLElement;
  declare dotTargets: HTMLElement[];
  declare btnPrevTarget: HTMLElement;
  declare btnNextTarget: HTMLElement;

  // This observer enables lazy loading of <turbo-frame> elements
  // when they are scrolled into view within the scrollable container.
  // It's necessary because Turbo's native lazy-loading does not
  // support elements inside scrollable containers.
  private observer?: IntersectionObserver;
  private readonly saveDebounced = debounce(300, () => this.save());

  initialize() {
    this.updateActiveDot = throttle(500, this.updateActiveDot.bind(this));
  }

  connect() {
    if (this.isMultiPage) {
      // Add a small delay to ensure the DOM is fully rendered
      requestAnimationFrame(() => {
        this.load();
        this.updateActiveDot();
        this.observeLazyFrames();
      });
    } else {
      this.observeLazyFrames();
    }

    this.scrollableTarget.addEventListener('scroll', this.saveDebounced);
  }

  disconnect() {
    this.observer?.disconnect();
    this.observer = undefined;

    this.scrollableTarget.removeEventListener('scroll', this.saveDebounced);
  }

  // Save current page
  save() {
    if (!this.scrollableTarget?.isConnected || !this.isMultiPage) return;

    const index = this.currentPageIndex();
    if (index >= 0) {
      sessionStorage.setItem(this.storageKey(), index.toString());
    }
  }

  // Restore current page
  load() {
    if (!this.isMultiPage) return;

    const savedIndex = parseInt(
      sessionStorage.getItem(this.storageKey()) ?? '',
      10,
    );

    if (isNaN(savedIndex) || savedIndex < 0) return;

    this.scrollableTarget.scrollLeft = savedIndex * this.pageWidth;
  }

  updateActiveDot() {
    if (!this.scrollableTarget || this.dotTargets.length === 0) return;

    const index = this.currentPageIndex();

    this.dotTargets.forEach((dot, i) => {
      const isActive = i === index;
      dot.classList.toggle('opacity-100', isActive);
      dot.classList.toggle('opacity-25', !isActive);
      dot.setAttribute('aria-selected', isActive.toString());
    });

    this.btnPrevTarget.classList.toggle('hidden', index === 0);
    this.btnNextTarget.classList.toggle(
      'hidden',
      index === this.dotTargets.length - 1,
    );
  }

  scrollToPage(event: Event) {
    const button = event.currentTarget as HTMLElement;
    const pageIndexStr = button.dataset.pageIndex;
    if (!pageIndexStr) return;

    const pageIndex = parseInt(pageIndexStr, 10);
    if (!Number.isInteger(pageIndex) || pageIndex < 0) return;

    this.scrollTo(pageIndex);
  }

  scrollToPreviousPage() {
    this.scrollTo(Math.max(this.currentPageIndex() - 1, 0));
  }

  scrollToNextPage() {
    this.scrollTo(this.currentPageIndex() + 1);
  }

  flashButton(button: HTMLElement): Promise<void> {
    button.classList.add('opacity-100', 'scale-125', 'bg-slate-50');

    return new Promise((resolve) => {
      setTimeout(() => {
        button.classList.remove('opacity-100', 'scale-125', 'bg-slate-50');
        resolve();
      }, 150);
    });
  }

  //////////

  private get isMultiPage(): boolean {
    return this.dotTargets.length > 1;
  }

  private get pageWidth(): number {
    return this.scrollableTarget?.clientWidth || 0;
  }

  private currentPageIndex(): number {
    const width = this.pageWidth;
    return width > 0 ? Math.round(this.scrollableTarget.scrollLeft / width) : 0;
  }

  private scrollTo(index: number) {
    this.scrollableTarget.scrollTo({
      left: index * this.pageWidth,
      behavior: 'smooth',
    });
  }

  private storageKey(): string {
    const key = this.keyValue || window.location.pathname;
    return `scroll-page:${key}`;
  }

  private observeLazyFrames() {
    // Clean up existing observer
    this.observer?.disconnect();

    // Create a new IntersectionObserver, scoped to the scrollable container
    this.observer = new IntersectionObserver(
      (entries) => {
        entries.forEach((entry) => {
          // Only proceed if the element is currently visible in the container
          if (!entry.isIntersecting) return;

          const frame = entry.target as HTMLElement;
          const src = frame.dataset.src;

          // Load the frame content only if not already loaded
          if (src && !frame.getAttribute('src')) {
            frame.setAttribute('src', src);
            // Remove data-src to avoid confusion
            delete frame.dataset.src;
          }

          // Stop observing this frame once it has been loaded
          this.observer?.unobserve(frame);
        });
      },
      {
        root: this.scrollableTarget, // use the scroll container as the viewport
        threshold: 0.2, // load when ~20% of the frame is visible
        rootMargin: '0px', // explicit root margin for clarity
      },
    );

    // Select all turbo-frame elements with a data-src attribute
    // These will be lazily loaded as they scroll into view
    const lazyFrames = this.scrollableTarget.querySelectorAll(
      'turbo-frame[data-src]',
    );
    lazyFrames.forEach((el) => this.observer?.observe(el));
  }
}
