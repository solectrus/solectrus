class Nav::Top::Component < ViewComponent::Base
  renders_many :items, 'ItemComponent'
  renders_one :sub_nav

  def current_item
    items.find(&:current?)
  end

  class ItemComponent < ViewComponent::Base
    def initialize(name:, href:)
      super
      @name = name
      @href = href
    end

    attr_reader :name, :href

    def current?
      current_page?(href) || (href == root_path && controller_name == 'home') ||
        (href.include?('top10') && controller_name == 'top10')
    end

    def call
      classes = %w[
        text-white
        rounded-md
        py-2
        px-3
        uppercase
        tracking-wider
        block
      ]

      if current?
        link_to name,
                href,
                class: classes + %w[bg-indigo-700],
                'aria-current': 'page'
      else
        link_to name,
                href,
                class: classes + %w[hover:bg-indigo-500 hover:bg-opacity-75]
      end
    end
  end
end
