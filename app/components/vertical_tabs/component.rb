class VerticalTabs::Component < ViewComponent::Base
  renders_many :tabs, 'TabComponent'

  class TabComponent < ViewComponent::Base
    def initialize(label)
      super
      @label = label
    end

    attr_reader :label

    def call
      content
    end
  end
end
