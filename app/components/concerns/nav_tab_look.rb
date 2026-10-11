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
  # It grows with the padding it hangs in: `py-1` up to the width where the
  # pill is drawn with `lg:landscape:py-2`. A phone shows none of it and has
  # the native select instead, which brings the chevron of its picker.
  #
  # The chevron is drawn on a box of its own size rather than taken from the
  # icon set, whose chevron spends four fifths of its box on air and would be
  # a hairline here.
  def menu_caret
    tag.svg(
      class: [
        'absolute left-1/2 -translate-x-1/2',
        'bottom-0.5 h-1 lg:landscape:bottom-1 lg:landscape:h-1.5',
        'hidden sm:block',
      ],
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
      py-1
      px-2
      lg:landscape:px-3
      lg:landscape:py-2
      flex-1
      lg:landscape:flex-initial
      text-center
      click-animation
    ]
  end

  def current_classes
    %w[
      text-gray-800
      bg-gray-200
      dark:bg-gray-400
      dark:text-gray-800
      rounded-full
      lg:landscape:rounded-md
      focus:outline-none
      focus:ring-2
      focus:ring-gray-800
      dark:focus:ring-slate-300
      focus:ring-offset-0
    ]
  end

  def idle_classes
    %w[
      text-gray-300
      dark:text-gray-400
      rounded-full
      lg:landscape:rounded-md
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
