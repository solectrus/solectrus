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
      base_classes = %w[pt-3 pb-5 px-3 md:py-2]

      if current
        base_classes + %w[bg-white text-gray-800]
      else
        base_classes +
          %w[text-gray-300 hover:text-gray-200 hover:bg-indigo-500 rounded]
      end
    end
  end
end
