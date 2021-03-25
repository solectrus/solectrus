class Nav::Sub::Component < ViewComponent::Base
  renders_many :items, 'ItemComponent'

  class ItemComponent < ViewComponent::Base
    def initialize(name:, href:)
      super
      @name = name
      @href = href
    end

    def call
      classes = %w[p-2 md:px-3]

      if current_page?(@href)
        link_to @name,
                @href,
                class: classes + %w[bg-gray-200 text-gray-800 rounded-md],
                'aria-current': 'location'
      else
        link_to @name,
                @href,
                class: classes + %w[text-gray-300 hover:text-gray-200 hover:bg-indigo-500 rounded]
      end
    end
  end
end
