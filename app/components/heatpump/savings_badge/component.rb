# The savings of the heat pump against a heating that burns oil or gas (see
# Heatpump::Comparison), beside the costs of the heat pump. It opens the page
# of the comparison. The admin sees it also without a result, so the page can
# lead to the settings. A visitor without the admin login sees it only with a
# result. The amounts come from the cache (see Heatpump::Savings).
#
# The desktop shows a badge of its own. A phone has no room for a third
# badge, and the costs matter more, so a compact link shows the savings
# below the costs: a piggy bank and the amount (`compact`). It opens the
# comparison in a sheet, like the savings of a car.
class Heatpump::SavingsBadge::Component < ViewComponent::Base
  include Car::ComparisonFormat

  def initialize(timeframe:, savings:, compact: false, css_class: nil)
    super()
    @timeframe = timeframe
    @savings = savings
    @compact = compact
    @css_class = css_class
  end

  attr_reader :timeframe, :css_class

  def compact? = @compact

  def render? = @savings.available? && (helpers.admin? || amounts.present?)

  # The savings as the page of the comparison shows them, nil without a
  # result
  delegate :amounts, :heating, to: :@savings

  def value_class = amounts ? savings_color_of(amounts.savings) : 'text-slate-500 dark:text-slate-400'

  def value = amounts ? amount(amounts.savings) : '–'

  def path = helpers.heatpump_savings_path(timeframe: timeframe.to_param)

  # The comparison in the sheet of a phone (see SheetPage)
  def sheet_path = helpers.heatpump_savings_path(timeframe: timeframe.to_param, sheet: 1)

  # The compact link has no word, so a screen reader hears its name
  def label = [t('heatpump_comparison.savings'), (currency(amounts.savings, precision: amounts.precision) if amounts)].compact.join(' ')

  # The tooltip of the costs badge beside it, only with a result
  def tooltip_data
    return {} unless amounts

    { controller: 'tooltip', tooltip_placement_value: 'bottom', tooltip_force_tap_to_close_value: false, tooltip_touch_value: 'long' }
  end
end
