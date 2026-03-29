class Nav::Sub::Component < ViewComponent::Base
  renders_many :items, 'ItemComponent'

  def initialize(abbreviate: true)
    super()
    @abbreviate = abbreviate
  end

  attr_reader :abbreviate

  def before_render
    return unless @abbreviate

    items.each_with_index do |item, index|
      item.abbreviate = index.positive? && index < items.size - 1
    end
  end

  class ItemComponent < ViewComponent::Base
    def initialize(name:, href:, current: false)
      super()
      @name = name
      @href = href
      @current = current
      @abbreviate = false
    end

    attr_reader :name, :href, :current
    attr_writer :abbreviate

    def call
      link_to href,
              class: css_classes,
              'aria-current': (current ? 'location' : nil) do
        safe_join(
          [
            tag.span(short_name, class: 'sm:hidden'),
            tag.span(name, class: 'hidden sm:inline'),
          ],
        )
      end
    end

    private

    def short_name
      @abbreviate ? name.first : name
    end

    def css_classes
      base_classes = %w[
        py-1
        px-2
        lg:landscape:px-3
        lg:landscape:py-2
        flex-1
        lg:landscape:flex-initial
        text-center
        click-animation
      ]

      if current
        base_classes +
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
      else
        base_classes +
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
  end
end
