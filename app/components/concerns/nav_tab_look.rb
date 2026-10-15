# What a tab of the sub navigation looks like, whether it leads to its
# timeframe or opens a menu. The two are separate components, so the look lives
# here rather than in one of them.
module NavTabLook
  attr_reader :name, :current
  attr_writer :abbreviate

  def label
    safe_join(
      [
        tag.span(short_name, class: 'sm:hidden'),
        tag.span(name, class: 'hidden sm:inline'),
      ],
    )
  end

  def css_classes
    base_classes + (current ? current_classes : idle_classes)
  end

  # A tab that opens a menu says so with a small chevron below its label. The
  # chevron is taken out of the flow and centered in the padding of the pill,
  # so the tab keeps exactly the width and the balance of every other tab in
  # the row: the row has no width to spend on a mark, and a tab that changes
  # width the moment it becomes the current one moves the whole row with it.
  #
  # It hangs in the padding of `py-2`, which also makes a tab tall enough to
  # hit with a finger. A phone shows none of it and has the native select
  # instead, which brings the chevron of its picker.
  #
  # The chevron is drawn on a box of its own size rather than taken from the
  # icon set, whose chevron spends four fifths of its box on air and would be
  # a hairline here.
  def menu_caret
    tag.svg(
      class: 'absolute left-1/2 -translate-x-1/2 bottom-1 h-1.5 hidden sm:block',
      viewbox: '0 0 10 5',
      fill: 'none',
      stroke: 'currentColor',
      'stroke-width': 1.5,
      'stroke-linecap': 'round',
      'stroke-linejoin': 'round',
      'aria-hidden': 'true',
    ) { tag.path(d: 'M1 1 5 4 9 1') }
  end

  private

  def short_name
    @abbreviate ? name.first : name
  end

  def base_classes
    %w[
      py-2
      px-2
      lg:landscape:px-3
      flex-1
      lg:landscape:flex-initial
      text-center
      relative
      touch-target
      transition-opacity
      rounded-md
    ]
  end

  # A phone shows the tabs as a segmented control: the current one is
  # the raised segment. A wide screen in landscape shows pills.
  def current_classes
    %w[
      bg-white
      text-indigo-700
      font-semibold
      lg:landscape:font-medium
      shadow-sm
      dark:bg-white/20
      dark:text-white
      lg:landscape:shadow-none
      lg:landscape:text-gray-800
      lg:landscape:bg-gray-200
      dark:lg:landscape:bg-gray-400
      dark:lg:landscape:text-gray-800
      focus:outline-none
      focus:ring-2
      focus:ring-gray-800
      dark:focus:ring-slate-300
      focus:ring-offset-0
    ]
  end

  # A tapped tab dims while the finger is on it, rather than
  # shrink. The current one stays as it is. A mouse gets no such
  # look: the marking moves on the click, and the tab would light up again.
  #
  # The transition sits in the base classes. The tap swaps the class lists of
  # the tabs while the tapped one is still fading back in, and a fade that
  # lost its transition there would jump to full opacity.
  def idle_classes
    %w[
      [&.is-pressed]:opacity-50
      text-white
      dark:text-slate-300
      lg:landscape:text-gray-300
      dark:lg:landscape:text-gray-400
      lg:landscape:hover:text-gray-200
      lg:landscape:hover:bg-indigo-500
      dark:lg:landscape:hover:bg-indigo-950/50
      dark:lg:landscape:hover:text-gray-300
      focus:outline-none
      focus:ring-2
      focus:ring-gray-300
      dark:focus:ring-gray-400
      focus:ring-offset-0
    ]
  end
end
