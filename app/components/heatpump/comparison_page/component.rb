# The comparison of the heat pump with a heating that burns oil or gas (see
# Heatpump::Comparison), on its page below the heat pump page. It shows the
# savings first, then the cost of each column as a bar, then the
# calculation of each column, step by step. It looks like the comparison of
# a car with a combustion car, whose format it shares (see
# Car::ComparisonFormat).
#
# Without a heating, without the prices of its fuel, or without heat to
# compare, it says why there is no comparison.
class Heatpump::ComparisonPage::Component < ViewComponent::Base
  include Car::ComparisonFormat

  # A step of a calculation: its operator (nil for the first), its label and
  # its value as HTML. A result stands below a line.
  Step = Data.define(:operator, :label, :value, :result)
  private_constant :Step

  # A column of the comparison: its key, its title, its total cost and its
  # steps by their slot. Beside the column without PV, the heat pump names
  # its PV system with a suffix, like the car.
  Column = Data.define(:key, :title, :total, :steps, :suffix) do
    def initialize(key:, title:, total:, steps:, suffix: nil) = super

    def color = COLUMN_COLORS[key]

    # The column that the button adds
    def without_pv? = key == :without_pv
  end
  private_constant :Column

  # The slots of the steps, so comparable steps of the three columns stand at
  # the same height: the heat and how it comes about, the energy cost, the
  # running costs and the total. The running costs of each column fill their
  # slots from the top: the payments of the heat pump by their category in
  # the order of the form, the running costs of the fossil heating in one.
  RUNNING_SLOTS = Heatpump::Payment::COMPARED.each_index.map { :"running_#{it}" }.freeze
  SLOTS = (%i[heat divisor quantity price energy_cost] + RUNNING_SLOTS + %i[total]).freeze
  private_constant :RUNNING_SLOTS, :SLOTS

  # The colors of the columns: those of the car, the car without PV and the
  # combustion car
  COLUMN_COLORS = { heatpump: COLORS[:car], without_pv: COLORS[:without_pv], heating: COLORS[:combustion] }.freeze
  private_constant :COLUMN_COLORS

  # The cookie of the column without PV. Without it, the comparison hides
  # the column. Its button sets it (see without_pv_toggle_controller.ts).
  WITHOUT_PV_COOKIE = :heatpump_comparison_without_pv
  public_constant :WITHOUT_PV_COOKIE

  # The heat pump without PV comes and goes with the button, like the car
  # without PV. CSS animates it alone, from the attribute of the root. A
  # part of it fades (WITHOUT_PV_FADE) or opens from no height.
  WITHOUT_PV_OPEN = "grid transition-[grid-template-rows] #{MOTION} grid-rows-[0fr] group-data-without-pv/comparison:grid-rows-[1fr]".freeze

  # The columns side by side, when the page has the width. The middle
  # track, the heat pump without PV, opens from no width while the others
  # narrow. Half the gap stands on each side of the closed track, so the gap
  # between the other two stays the same. Stacked, the columns have a margin
  # instead of a gap, so the closed track leaves no gap.
  GRID = "grid grid-cols-1 [--gap:1.5rem] lg:[--gap:3.5rem] @3xl:grid-cols-[minmax(0,1fr)_minmax(0,0fr)_minmax(0,1fr)] @3xl:gap-x-[calc(var(--gap)/2)] @3xl:transition-[grid-template-columns,column-gap] #{MOTION} @3xl:group-data-without-pv/comparison:grid-cols-[minmax(0,1fr)_minmax(0,1fr)_minmax(0,1fr)] @3xl:group-data-without-pv/comparison:gap-x-(--gap)".freeze

  # The track of the heat pump without PV. Stacked, it opens from no height.
  # Inside, the column fades and keeps its final width, a third of the grid
  # without its gaps, so its text does not wrap while it opens.
  WITHOUT_PV_TRACK = "grid min-w-0 overflow-hidden transition-[grid-template-rows] #{MOTION} @max-3xl:grid-rows-[0fr] @max-3xl:group-data-without-pv/comparison:grid-rows-[1fr]".freeze
  WITHOUT_PV_WIDTH = '@3xl:w-[calc((100cqw-2*var(--gap))/3)]'.freeze

  # The figure without PV beside the savings: on a desktop, it fades and
  # keeps its place. A phone wraps it below the savings, where its place
  # would be an empty gap, so it goes away there.
  WITHOUT_PV_FIGURE = "#{WITHOUT_PV_FADE} max-lg:hidden max-lg:group-data-without-pv/comparison:block".freeze
  private_constant :WITHOUT_PV_OPEN, :GRID, :WITHOUT_PV_TRACK, :WITHOUT_PV_WIDTH, :WITHOUT_PV_FIGURE

  def self.without_pv?(cookies) = cookies[WITHOUT_PV_COOKIE] == 'true'

  # `without_pv` shows the column without PV (see .without_pv?)
  def initialize(comparison:, without_pv: false)
    super()
    @comparison = comparison
    @without_pv = without_pv
  end

  attr_reader :comparison

  def without_pv? = @without_pv

  delegate :heating, :state, to: :comparison

  # The amounts as the page shows them, so each column adds up
  def amounts = @amounts ||= Heatpump::ComparisonAmounts.new(comparison)

  # The track of a column and the classes of its card. Only the column
  # without PV has a track that opens.
  def track_class(column) = column.without_pv? ? WITHOUT_PV_TRACK : 'min-w-0'
  def fade_class(column) = (WITHOUT_PV_FADE if column.without_pv?)

  def card_classes(column, index)
    [CARD, 'min-w-0 p-4 md:p-5 lg:p-0', ('@max-3xl:mt-4' if index.positive?), (WITHOUT_PV_WIDTH if column.without_pv?)]
  end

  # The bar of a column. Each bar but the first has its space above it, so
  # the closed bar without PV leaves no gap. That bar opens from no height
  # and fades.
  def bar_wrap(column, index, &)
    bar = tag.div(class: ('pt-4' if index.positive?), &)
    return bar unless column.without_pv?

    tag.div(class: WITHOUT_PV_OPEN) { tag.div(class: 'min-h-0 overflow-hidden') { tag.div(bar, class: WITHOUT_PV_FADE) } }
  end

  def columns
    @columns ||= [
      Column.new(key: :heatpump, title: t('.heatpump'), total: amounts.heatpump_cost, steps: heatpump_steps(amounts.energy_cost, amounts.heatpump_cost, cost_path:), suffix: t('.with_pv')),
      Column.new(key: :without_pv, title: t('.without_pv'), total: amounts.without_pv_cost, steps: heatpump_steps(amounts.energy_cost_without_pv, amounts.without_pv_cost)),
      Column.new(key: :heating, title: heating.name.upcase_first, total: amounts.heating_cost, steps: heating_steps),
    ]
  end

  # The chart of the periods below the calculation, with the columns in their
  # order and colors
  def chart = Heatpump::ComparisonChart::Component.new(comparison:, columns:)

  # The slots that a column fills
  def slots = SLOTS.select { |slot| columns.any? { it.steps[slot] } }

  # The classes of the cells of a slot: a result stands below a line. An
  # empty slot beside a result keeps its height with a clear line.
  def line_class(slot, step)
    return unless columns.any? { it.steps[slot]&.result }

    "border-t pt-1.5 #{step&.result ? 'border-slate-300 dark:border-slate-600' : 'border-transparent'}"
  end

  # The info tooltip of the savings: how they come about, and the data they
  # need as a list
  def savings_notes = [t('.notes.savings'), t('.notes.data')]

  # The info tooltip of each column: what it is, what its energy costs, and
  # which running costs add to it
  def notes_of(column)
    case column.key
    when :heatpump then [t('.notes.heatpump_intro'), t('.notes.heatpump'), t('.notes.payments')]
    when :without_pv then [t('.notes.without_pv_intro'), t('.notes.without_pv')]
    when :heating then [t('.notes.heating_intro'), fuel_note, t('.notes.running_costs')]
    end
  end

  # The warning above the figures about the days that the comparison leaves
  # out, nil without one
  def left_out_warning
    t('.notes.left_out', count: comparison.left_out_days) if comparison.left_out_days.positive?
  end

  # The button of the admin to the settings of the heating
  def settings_button
    return unless helpers.admin?

    Ui::Button::Component.new(href: helpers.edit_settings_heatpump_path, label: t('.to_settings'), icon: 'pencil')
  end

  private

  # The heat and the seasonal performance factor give the electricity of the
  # heat pump, and the electricity its costs. The column without PV has the
  # same electricity at the electricity price. The payments add to it, each
  # category in a row of its own. The energy cost links to `cost_path`, also
  # as the total without payments.
  def heatpump_steps(energy_cost, total, cost_path: nil)
    steps = {
      heat: step(nil, :heat, energy(comparison.heat_wh)),
      divisor: (step('÷', :cop, decimal_number(comparison.cop, precision: 2)) if comparison.cop),
      quantity: step('=', :electricity, energy(comparison.power_wh), result: true),
    }.compact
    payments = payment_steps(amounts.payment_costs)
    return steps.merge(total: step(nil, :total, linked(amount(total), cost_path), result: true)) if payments.none?

    steps.merge(energy_cost: step(nil, :electricity_cost, linked(amount(energy_cost), cost_path), result: true), **payments, total: step('=', :total, amount(total), result: true))
  end

  # The heat and the efficiency give the fuel, the fuel at the price of each
  # day its cost, and the running costs of the heating add to it. The prices
  # vary, so the page shows their range and no average. The running costs
  # show also without an amount, so a missing amount stands out.
  def heating_steps
    {
      heat: step(nil, :heat, energy(comparison.heat_wh)),
      divisor: step('÷', :efficiency, "#{heating.efficiency} %"),
      quantity: step('=', "fuel.#{heating.fuel_type}", fuel_quantity, result: true),
      price: step('×', :price, price_range),
      energy_cost: step('=', "fuel_cost.#{heating.fuel_type}", amount(amounts.fuel_cost), result: true),
      RUNNING_SLOTS.first => step('+', :running_costs, amount(amounts.fixed_cost)),
      total: step('=', :total, amount(amounts.heating_cost), result: true),
    }
  end

  # A step for each category of the payments, with the label of the form,
  # in the running slots from the top. The categories come in the order of
  # the form (see Heatpump::Payment::COMPARED). Each amount links to the
  # payments of its category.
  def payment_steps(costs)
    costs.each_with_index.to_h do |(category, cost), index|
      value = linked(amount(cost.abs), payments_path(category))
      [RUNNING_SLOTS[index], Step.new(operator: cost.negative? ? '−' : '+', label: Heatpump::Payment.human_enum_name(:category, category), value:, result: false)]
    end
  end

  # The costs on the heat pump page, where they are the same costs
  def cost_path
    helpers.heatpump_home_path(sensor_name: 'heatpump_costs', timeframe: comparison.timeframe.to_param) if comparison.whole_cost?
  end

  # The list of the payments of a category in the years of the comparison.
  # Only the admin opens it.
  def payments_path(category)
    helpers.settings_heatpump_payments_path(comparison.payment_filter([category]).to_params) if helpers.admin?
  end

  # A value with a link to `href`, or the value alone without one
  def linked(value, href) = href ? helpers.link_to(value, href, class: LINK) : value

  # Where the price of the fuel comes from
  def fuel_note
    t(".notes.#{heating.fuel_type}", kwh_per_liter: helpers.number_with_precision(heating.fuel.kwh_per_unit, precision: 1))
  end

  # The fuel in its unit of sale. Gas is sold by the kWh, so it has the
  # format of an energy.
  def fuel_quantity
    return energy(comparison.fuel_wh) if heating.fuel.unit == 'kWh'

    helpers.safe_join([decimal_number(comparison.fuel_units, precision: quantity_precision(comparison.fuel_units)), ' ', helpers.tag.small(t('.liters'), class: 'font-light')])
  end

  # The lowest and the highest price, one price if they look the same. The
  # range opens the modal of the prices, like the price of the fuel in the
  # comparison of a car.
  def price_range
    precision = heating.fuel.price_precision
    prices = shown_prices(*comparison.fuel_price_extremes.map(&:last), precision:)
    text = helpers.safe_join([helpers.safe_join(prices.map { decimal_number(it, precision:) }, ' – '), " #{Currency.symbol}/#{heating.fuel.unit}"])
    helpers.link_to(text, helpers.heatpump_fuel_prices_path(timeframe: comparison.timeframe.to_param), class: LINK, data: Ui::TurboModal::Component.link_data)
  end

  def energy(value_wh) = render(Sensor::Value::Component.new(value_wh, :heatpump_heating_power, context: :total))

  def step(operator, key, value, result: false) = Step.new(operator:, label: t(".steps.#{key}"), value:, result:)
end
