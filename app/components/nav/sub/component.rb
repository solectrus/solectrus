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
      base_classes = %w[py-3 px-2 sm:py-2 sm:px-3]

      if current
        base_classes + %w[bg-gray-200 text-gray-800 rounded-md]
      else
        base_classes +
          %w[text-gray-300 hover:text-gray-200 hover:bg-indigo-500 rounded]
      end
    end
  end
end
