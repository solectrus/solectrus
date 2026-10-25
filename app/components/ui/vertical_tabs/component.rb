# Tabs at the left of their panels from md up, above them on a smaller
# screen. The first tab is selected, unless the hash of the address names
# the id of another one. All panels stay in the page, so a form around them
# submits the fields of every tab.
#
#   = render Ui::VerticalTabs::Component.new do |c|
#     = c.with_tab id: 'inverter', label: 'Inverter' do
#       = render 'inverter', f:
class Ui::VerticalTabs::Component < ViewComponent::Base
  renders_many :tabs, 'TabComponent'

  # The selected tab takes its look from aria-selected, which the controller
  # sets
  TAB_CLASS =
    'flex md:rounded-md py-3 md:py-2 px-3 text-gray-700 dark:text-gray-300 ' \
    'not-aria-selected:hover:bg-gray-100 dark:not-aria-selected:hover:bg-gray-800 ' \
    'aria-selected:bg-gray-200 aria-selected:text-gray-800 dark:aria-selected:bg-gray-700 dark:aria-selected:text-gray-200'.freeze
  private_constant :TAB_CLASS

  def tab_id(tab) = "#{tab.id}-tab"

  class TabComponent < ViewComponent::Base
    def initialize(id:, label:)
      super()
      @id = id
      @label = label
    end

    attr_reader :id, :label

    def call
      content
    end
  end
end
