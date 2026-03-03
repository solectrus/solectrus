class Nav::Sub::Component < ViewComponent::Base
  renders_many :items, 'ItemComponent'

  class ItemComponent < ViewComponent::Base
    def initialize(name:, href:, current: false)
      super()
      @name = name
      @href = href
      @current = current
    end

    attr_reader :name, :href, :current

    def call
      link_to name,
              href,
              class: css_classes,
              'aria-current': (current ? 'location' : nil)
    end

    private

    def css_classes # rubocop:disable Metrics/MethodLength
      base_classes = %w[
        py-5
        standalone:max-lg:pt-3
        standalone:max-lg:pb-8
        px-1.5
        first:pl-6
        last:pr-6
        md:px-3
        md:first:pl-3
        md:last:pr-3
        lg:landscape:py-2
        flex-auto
        text-center
        click-animation
      ]

      if current
        base_classes +
          %w[
            from-white
            to-indigo-100
            bg-linear-to-b
            text-gray-800
            lg:landscape:rounded-md
            lg:landscape:bg-gray-200
            lg:landscape:bg-none
            dark:from-gray-800
            dark:to-indigo-700
            dark:text-slate-300
            dark:lg:landscape:bg-gray-400
            dark:lg:landscape:text-gray-800
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
            lg:landscape:hover:text-gray-200
            lg:landscape:hover:bg-indigo-500
            dark:lg:landscape:hover:bg-indigo-950/50
            dark:lg:landscape:hover:text-gray-300
            rounded
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
