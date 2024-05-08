class Nav::Sub::Component < ViewComponent::Base
  renders_many :items, 'ItemComponent'

  class ItemComponent < ViewComponent::Base
    def initialize(name:, href:, current: false)
      super
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

    def css_classes
      base_classes = %w[
        pt-5
        pb-5
        standalone:pt-3
        standalone:pb-8
        px-2
        first:pl-6
        last:pr-6
        md:px-3
        md:first:pl-3
        md:last:pr-3
        lg:py-2
        flex-auto
        text-center
        click-animation
      ]

      if current
        base_classes +
          %w[
            from-white
            to-indigo-100
            bg-gradient-to-b
            text-gray-800
            lg:rounded-md
            lg:bg-gray-200
            lg:bg-none
          ]
      else
        base_classes +
          %w[
            text-gray-300
            lg:hover:text-gray-200
            lg:hover:bg-indigo-500
            rounded
          ]
      end
    end
  end
end
