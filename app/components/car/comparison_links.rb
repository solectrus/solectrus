# The links of the calculation of the comparison with a combustion car (see
# Car::ComparisonColumns::Component). A number links to a drill-down only where
# its target shows the same number: a chart of the car page, the settings of
# the car, or the modal of the fuel prices. The payments link to the list of the payments that they come from,
# which shows them in full. A number without a target can explain its parts
# in a tooltip instead. A title never links. The component has the report, the comparison, its amounts, the
# timeframe and `@car`, the parameter of the selected car, nil for "all".
module Car::ComparisonLinks
  # A link in the text of the page: a dotted line in the color of the text,
  # because a blue link everywhere would be restless
  LINK = 'border-b border-dotted border-slate-400 hover:border-solid dark:border-slate-500 rounded-sm focus-ring'.freeze
  private_constant :LINK

  # A value with a link to `href`, in the modal with `modal: true`, or with
  # a tooltip of its parts (see #explained). Without either, the value alone.
  def linked(value, href, modal: false, tooltip: nil)
    return explained(value, tooltip) if tooltip
    return value unless href

    link_to(value, href, class: LINK, data: ({ turbo_frame: 'modal', controller: 'modal-launcher' } if modal))
  end

  # The distance of the comparison on the car page, where it shows the same
  # distance
  def distance_path
    car_page_path(:car_distance) if comparison.whole_distance?
  end

  # The driving cost of the comparison on the car page, where it shows the
  # same number
  def driving_cost_path
    car_page_path(:car_driving_costs) if comparison.driving_distance?
  end

  # The electricity cost per 100 km of the comparison on the car page, where
  # it shows the same number
  def cost_rate_path
    car_page_path(:car_cost_rate) if comparison.driving_distance?
  end

  # The consumption per 100 km of the comparison on the car page, where it
  # shows the same number
  def consumption_path
    car_page_path(:car_consumption_rate) if comparison.consumption_distance?
  end

  # The settings of the one combustion car, which show its consumption
  def settings_path
    helpers.edit_settings_car_path(comparison.cars.sole) if helpers.admin? && comparison.cars.one?
  end

  # The prices of the fuel in the modal (see Car::FuelPriceChart::Component),
  # which shows the same lowest and highest price
  def fuel_prices_path
    helpers.cars_fuel_prices_path(car: @car, timeframe: timeframe.to_param) if comparison.fuel_price_range
  end

  # The list of the payments of the comparison, filtered to the payments
  # that it counts, or to some of their categories (see
  # Car::Comparison#payment_filter). Only the admin opens it.
  def payments_path(categories)
    helpers.settings_car_payments_path(comparison.payment_filter(categories).to_params) if helpers.admin?
  end

  # [[label, amount], ...] of the payments of the combustion car: the
  # running costs that it shares with the car, and its tax. Nil without the
  # running costs, because the row then names the tax.
  def payments_parts
    return if amounts.shared_cost.zero?

    yearly = comparison.yearly_tax
    tax_label = yearly&.positive? ? t('.parts.tax_yearly', yearly: currency(yearly)) : t('.parts.tax')
    [[t('.parts.shared'), amounts.shared_cost], ([tax_label, amounts.tax] if amounts.tax.nonzero?)].compact
  end

  private

  # A value in the look of a link that shows its parts in a tooltip, each
  # with its label and its amount. A touch opens it too.
  def explained(value, parts)
    tag = helpers.tag
    rows = parts.map { |label, amount| tag.div(class: 'flex justify-between gap-4') { tag.span(label) + tag.span(currency(amount), class: 'tabular-nums whitespace-nowrap') } }
    tag.span(class: "#{LINK} cursor-help", data: { controller: 'tooltip', tooltip_touch_value: true }) do
      value + tag.span(helpers.safe_join(rows), class: 'hidden', data: { tooltip_target: 'html' })
    end
  end

  # A chart of the car page in the timeframe, with the selected car
  def car_page_path(sensor_name)
    helpers.cars_home_path(sensor_name:, timeframe: timeframe.to_param, car: @car)
  end
end
