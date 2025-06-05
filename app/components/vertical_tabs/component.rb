class VerticalTabs::Component < ViewComponent::Base
  renders_many :tabs, 'TabComponent'

  class TabComponent < ViewComponent::Base
    def initialize(id:, label:)
      super
      @id = id
      @label = label
    end

    attr_reader :id, :label

    def call
      content
    end
  end
end
