class TopNav::Component < ViewComponent::Base
  include ViewComponent::SlotableV2

  renders_many :links, 'LinkComponent'

  class LinkComponent < ViewComponent::Base
    def initialize(name:, href:)
      super
      @name = name
      @href = href
    end

    def call
      classes = %w[text-white rounded-md py-2 px-3 uppercase tracking-wider block]

      if current_page?(@href) || @href == root_path && controller_name == 'home'
        link_to @name, @href, class: classes + %w[bg-indigo-700]
      else
        link_to @name, @href, class: classes + %w[hover:bg-indigo-500 hover:bg-opacity-75]
      end
    end
  end
end
