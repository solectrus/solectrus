# The parameters of the calculation behind a button, for a screen without
# room for the sliders in the bar. The button opens them in a sheet (a
# dialog from md up). In the title bar of a phone the button is round, and an
# amber dot on it says that the projection is uncertain. The sheet then says
# why, above the sliders.
class Amortization::Options::Component < ViewComponent::Base
  BUTTON_CLASS =
    'rounded-md p-2 text-gray-300 hover:bg-indigo-500 dark:text-gray-400 dark:hover:bg-indigo-950/50 focus:outline-none focus:ring-2 focus:ring-gray-300 dark:focus:ring-gray-400 focus:ring-offset-0'.freeze
  # The look of the save button of Ui::SheetPage::Component
  DONE_CLASS =
    'flex size-9 items-center justify-center rounded-full bg-indigo-600 text-white click-animation focus-ring'.freeze
  private_constant :BUTTON_CLASS, :DONE_CLASS

  def initialize(period_years:, interest_rate:, view:, projection_uncertain:, title_bar: false)
    super()
    @period_years = period_years
    @interest_rate = interest_rate
    @view = view
    @projection_uncertain = projection_uncertain
    @title_bar = title_bar
  end

  attr_reader :period_years, :interest_rate, :view

  def title_bar? = @title_bar

  def warning? = @projection_uncertain

  # The bar of a wide screen has the warning next to the button
  def dot? = warning? && title_bar?

  # The page renders the component twice, in the title bar and in the row
  def sheet_id = "amortization-options-#{title_bar? ? 'title-bar' : 'row'}"

  def button_class
    title_bar? ? 'ui-title-bar-action click-animation' : BUTTON_CLASS
  end

  def icon_class
    'fa-xl block' unless title_bar?
  end

  def done_class = DONE_CLASS
end
