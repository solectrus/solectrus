# The calculation of each column of the comparison with a combustion car
# (see Car::ComparisonPage::Component), step by step, so the user can follow
# it. Each column shows only its costs, until a click on the page shows the
# details of the calculation too. Each column explains itself in an info
# tooltip beside its title (see Car::ComparisonNotes). A number links to the
# place it comes from where one exists (see Car::ComparisonLinks).
class Car::ComparisonColumns::Component < ViewComponent::Base
  include Car::ComparisonFormat
  include Car::ComparisonLinks
  include Car::ComparisonNotes

  # A step of a calculation: its operator (nil for the first), its label,
  # its number as HTML with its link (see Car::ComparisonLinks) and its unit
  # apart, so the numbers align to the right and the units to the left. A
  # result stands below a line.
  Step = Data.define(:operator, :label, :number, :unit, :result)
  public_constant :Step

  # The slots of the steps, so comparable steps of the three columns stand at
  # the same height: the consumption, the distance, the energy or the fuel,
  # up to three parts of its cost (the sources of the energy, or the prices
  # of the fuel), the cost of the energy and its cost per 100 km, the
  # other costs in one row, the payments by their category in the order of
  # the form, the total and the total per 100 km. The tax of the combustion
  # car stands beside the vehicle tax of the car. A column without a step of
  # a slot has an empty row there.
  PAYMENT_SLOTS = ((Car::Payment::EXPENSES + Car::Payment::INCOMES) & Car::Payment::COMPARED).map(&:to_sym).freeze
  private_constant :PAYMENT_SLOTS

  SLOTS = (%i[per_100km distance quantity part_0 part_1 part_2 energy_cost energy_cost_per_100km other_costs] + PAYMENT_SLOTS + %i[total total_per_100km]).freeze
  private_constant :SLOTS

  # The slots that only the details show: how the energy and its cost come
  # about, and each category of the payments. Without the details, each
  # column starts with its energy cost, and the other costs take one row.
  DETAIL_SLOTS = (%i[per_100km distance quantity part_0 part_1 part_2 energy_cost_per_100km] + PAYMENT_SLOTS).freeze
  private_constant :DETAIL_SLOTS

  # The classes of a row by its visibility, [with a step, empty]. An empty
  # slot does not show on a phone.
  ROW_CLASSES = {
    detail: ['hidden group-data-expanded/details:table-row', 'hidden md:group-data-expanded/details:table-row'],
    summary: ['group-data-expanded/details:hidden', 'max-md:hidden group-data-expanded/details:hidden'],
    always: [nil, 'max-md:hidden'],
  }.freeze
  private_constant :ROW_CLASSES

  # `columns` are the columns of the page (see
  # Car::ComparisonPage::Component::Column), `amounts` the amounts that the
  # page shows. `car` is the parameter of the selected car, nil for "all",
  # which each link to the car page keeps.
  def initialize(report:, car:, columns:, amounts:)
    super()
    @report = report
    @car = car
    @columns = columns
    @amounts = amounts
  end

  attr_reader :columns, :amounts

  delegate :comparison, :timeframe, to: :@report

  # The steps of a column by their slot
  def steps_of(column)
    (@steps ||= {})[column.key] ||=
      case column.key
      when :car then electric_steps(amounts.source_costs, :car_cost, linked: true)
      when :without_pv then electric_steps(amounts.source_costs_without_pv, :car_cost_without_pv)
      when :combustion then combustion_steps
      end
  end

  # The notes of the info tooltip of a column (see Car::ComparisonNotes)
  def notes_of(column) = public_send(:"#{column.key}_notes")

  # The slots that a column fills
  def slots = SLOTS.select { |slot| columns.any? { steps_of(it)[slot] } }

  # The classes of the row of a slot. A detail shows only with the details,
  # the other costs in one row only without them. The energy cost is a
  # result of the details and, without them, the first row.
  def row_class(slot, step)
    visibility =
      if DETAIL_SLOTS.include?(slot) then :detail
      elsif slot == :other_costs then :summary
      else :always
      end
    weight = slot == :energy_cost ? 'group-data-expanded/details:font-semibold' : ('font-semibold' if step&.result)

    helpers.class_names(ROW_CLASSES[visibility][step ? 0 : 1], weight)
  end

  # The classes of the operator of a slot. The energy cost has its operator
  # only with the details.
  def operator_class(slot) = ('hidden group-data-expanded/details:inline' if slot == :energy_cost)

  # The classes of the cells of a slot: a result stands below a line. An
  # empty slot beside a result keeps its height with a clear line. The line
  # of the energy cost shows only with the details.
  def cell_class(slot, step)
    return unless columns.any? { steps_of(it)[slot]&.result }
    return 'group-data-expanded/details:border-t group-data-expanded/details:pt-1.5 border-slate-300 dark:border-slate-600' if slot == :energy_cost

    "border-t pt-1.5 #{step&.result ? 'border-slate-300 dark:border-slate-600' : 'border-transparent'}"
  end

  private

  # The consumption at the distance gives the energy, and the costs of the
  # sources of the energy add up to the cost of the energy. The payments add
  # to it, each category in a row of its own. Without the details, one row
  # holds them, less the GHG quota where they have one, and links to all
  # payments of the comparison. The car links its consumption and its cost
  # to the car page, which has no cost without PV. `cost` names the cost of
  # the column.
  def electric_steps(source_costs, cost, linked: false)
    payments = payment_steps(amounts.payment_costs)
    additions = additions(amounts.public_send(cost), **payments)
    other_costs = other_costs_step(payments) do
      key = payments.key?(:ghg_quota) ? :payments_less_ghg_quota : :payments
      addition(key, amounts.payments, payments_path(Car::Payment::COMPARED))
    end
    {
      per_100km: step(nil, :consumption, energy_cell(comparison.per_100km(comparison.energy_wh), (consumption_path if linked), precision: 1)),
      **distance_step,
      quantity: step('=', :energy, energy_cell(comparison.energy_wh, precision: 0), result: true),
      **source_steps(source_costs),
      energy_cost: step('=', :energy_cost, money_cell(source_costs.values.sum, (driving_cost_path if linked)), result: true),
      **energy_per_100km_step(cost, additions, (cost_rate_path if linked)),
      **other_costs,
      **additions,
      **per_100km_step(:total_per_100km, cost),
    }
  end

  # A step for each category of the payments, with the label of the form,
  # linked to its payments
  def payment_steps(costs)
    costs.to_h do |category, amount|
      [category.to_sym, addition(category, amount, payments_path([category]), label: Car::Payment.human_enum_name(:category, category))]
    end.compact
  end

  # Without the details, one row holds the payments (`steps`). A single
  # step keeps its row, and the block gives the row of more.
  def other_costs_step(steps)
    { other_costs: steps.size > 1 ? yield : steps.values.first }.compact
  end

  # The slot of each source, so a source stands at the same height in both
  # columns of the car: the grid of the car without PV beside the grid of
  # the car.
  SOURCE_SLOTS = { pv: :part_0, grid: :part_1, offsite: :part_2 }.freeze
  private_constant :SOURCE_SLOTS

  # A step for the cost of each source. The first step follows the energy,
  # so it has no operator.
  def source_steps(costs)
    costs.each_with_index.to_h do |(source, cost), index|
      [SOURCE_SLOTS[source], step(('+' if index.positive?), source, money_cell(cost))]
    end
  end

  # The consumption at the distance gives the fuel, the fuel at the price of
  # each day the fuel cost, and the shared payments and the tax add to it.
  # The prices vary, so the page shows their range and no average. The
  # range opens the modal of the prices.
  def combustion_steps
    payments = combustion_payments
    additions = additions(amounts.combustion_cost, **payments)
    {
      per_100km: step(nil, :consumption, text_cell(decimal_number(comparison.consumption, precision: 1), t('.liters'), settings_path)),
      **distance_step,
      quantity: step('=', :fuel, text_cell(decimal_number(comparison.liters, precision: 0), t('.liters')), result: true),
      part_0: step(nil, :fuel_price, price_range_cell(comparison.fuel_price_range, fuel_prices_path)),
      energy_cost: step('=', :fuel_cost, money_cell(amounts.fuel_cost), result: true),
      **energy_per_100km_step(:combustion_cost, additions),
      **combustion_other_costs(payments),
      **additions,
      **per_100km_step(:total_per_100km, :combustion_cost),
    }
  end

  # The payments that the combustion car shares with the car, and its tax
  # beside the vehicle tax of the car
  def combustion_payments
    shared = payment_steps(amounts.payment_costs.slice(*Car::Payment::SHARED))
    { **shared, vehicle_tax: addition(:tax, amounts.tax) }.compact
  end

  # Without the details, one row holds the payments of the combustion car.
  # It has no link, because the list of the payments does not hold the tax.
  # A tooltip gives the two parts instead (see
  # Car::ComparisonLinks#payments_parts).
  def combustion_other_costs(payments)
    other_costs_step(payments) { addition(:payments, amounts.shared_cost + amounts.tax, tooltip: payments_parts) }
  end

  # The energy cost of the comparison in the total cost of each column
  ENERGY_COSTS = { car_cost: :cost, car_cost_without_pv: :cost_without_pv, combustion_cost: :fuel_cost }.freeze
  private_constant :ENERGY_COSTS

  # The energy cost per 100 km below the energy cost (`cost` names the total
  # cost of the column), like the chart of the weeks. Without an amount that
  # adds to the energy cost, it is the total, and the running costs per 100
  # km below give the same number.
  def energy_per_100km_step(cost, additions, href = nil)
    return {} if additions.empty?

    per_100km_step(:energy_cost_per_100km, ENERGY_COSTS[cost], href)
  end

  # A cost of the comparison per 100 km in a slot, nothing without a
  # distance. The running costs per 100 km stand below the total. The rate
  # of the car page holds no payments, so their row has no link.
  def per_100km_step(slot, cost, href = nil)
    value = amounts.per_100km(cost)
    value ? { slot => step(nil, :per_100km, money_cell(value, href, precision: 2)) } : {}
  end

  def distance_step = { distance: step('×', :distance, sensor_cell(comparison.distance, :car_distance, distance_path)) }

  # The steps of the amounts that add to the cost by their slot, and the
  # total below them, nothing without an amount
  def additions(total, **steps)
    steps.compact!
    return {} if steps.empty?

    { **steps, total: step('=', :total, money_cell(total), result: true) }
  end

  # An amount that adds to the cost or, as an income, takes from it, with
  # the label of `key` or `label`, nil for zero. The operator carries the
  # sign, so the amount has none.
  def addition(key, amount, href = nil, tooltip: nil, label: nil)
    return if amount.round(2).zero?

    step(amount.negative? ? '−' : '+', key, money_cell(amount.abs, href, tooltip:), label:)
  end

  def step(operator, key, (number, unit), result: false, label: nil) = Step.new(operator:, label: label || t(".steps.#{key}"), number:, unit:, result:)

  # [number, unit] of a step: the number of a value with its link, and the
  # unit of the value apart.
  def sensor_cell(value, sensor_name, href = nil, tooltip: nil, **)
    component = Sensor::Value::Component.new(value, sensor_name, unit: false, **)
    [linked(render(component), href, tooltip:), component.unit]
  end

  # An energy in kWh, like the consumption of the car page. Its unit is Wh.
  def energy_cell(value_wh, href = nil, precision:) = sensor_cell(value_wh, :wallbox_power, href, context: :total, scaling: :kilo, precision:)

  # An amount in whole units, like #money
  def money_cell(value, href = nil, precision: 0, **) = sensor_cell(value, :total_costs, href, precision:, **)

  def text_cell(number, unit, href = nil) = [linked(number, href), unit]

  # [number, unit] of the lowest and the highest price per liter, one price
  # if they are the same. The range opens the modal of the prices.
  def price_range_cell(range, href)
    return money_cell(nil, precision: 2) unless range

    prices = [range.begin, range.end].uniq.map { Sensor::Value::Component.new(it, :total_costs, unit: false, precision: 2) }
    number = helpers.safe_join(prices.map { render(it) }, ' – ')
    [linked(number, href, modal: true), prices.first.unit]
  end
end
