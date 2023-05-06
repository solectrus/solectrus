class Calculator::Range < Calculator::Base
  def initialize(timeframe)
    super()

    sums =
      PowerSum.new(
        measurements: %w[SENEC Forecast],
        fields: fields(timeframe),
      ).call(timeframe)

    build_context sums
  end

  def fields(timeframe)
    result = %i[
      inverter_power
      house_power
      wallbox_charge_power
      grid_power_plus
      grid_power_minus
      bat_power_minus
      bat_power_plus
      feed_in_tariff
      electricity_price
    ]

    # Include forecast for days only
    result << :watt if timeframe.day?

    result
  end

  def forecast_deviation
    return unless respond_to?(:watt)
    return if watt.zero?

    ((inverter_power * 100.0 / watt) - 100).round
  end

  def paid
    return unless grid_power_plus

    -section_sum do |index|
      grid_power_plus_array[index] * electricity_price[index]
    end
  end

  def got
    return unless grid_power_minus

    section_sum do |index|
      grid_power_minus_array[index] * feed_in_tariff[index]
    end
  end

  def solar_price
    return unless got && paid

    got + paid
  end

  def traditional_price
    return unless consumption

    -section_sum { |index| consumption_array[index] * electricity_price[index] }
  end

  def savings
    return unless solar_price && traditional_price

    solar_price - traditional_price
  end

  def battery_savings
    return unless bat_power_minus && bat_power_plus && savings

    [
      section_sum do |index|
        (bat_power_minus_array[index] * electricity_price[index]) -
          (bat_power_plus_array[index] * feed_in_tariff[index])
      end,
      savings,
    ].min
  end

  def battery_savings_percent
    return unless savings && battery_savings
    return if savings.zero?

    (battery_savings * 100.0 / savings).round
  end

  def wallbox_costs
    return unless wallbox_charge_power && grid_power_plus

    @wallbox_costs ||=
      -section_sum do |index|
        if wallbox_charge_power_array[index] > grid_power_plus_array[index]
          # Part 1: Paid to the power supplier
          grid_costs = grid_power_plus_array[index] * electricity_price[index]

          # Part 2: Lost feed-in tariff
          opportunity_costs =
            (wallbox_charge_power_array[index] - grid_power_plus_array[index]) *
              feed_in_tariff[index]

          grid_costs + opportunity_costs
        else
          # It all comes from the grid
          wallbox_charge_power_array[index] * electricity_price[index]
        end
      end
  end

  def house_costs
    return unless house_power

    @house_costs ||=
      -section_sum do |index|
        if wallbox_charge_power_array[index] < grid_power_plus_array[index]
          # Part 1: Paid to the power supplier
          grid_costs =
            (grid_power_plus_array[index] - wallbox_charge_power_array[index]) *
              electricity_price[index]

          # Part 2: Lost feed-in tariff
          consume = wallbox_charge_power_array[index] + house_power_array[index]
          opportunity_costs =
            (consume - grid_power_plus_array[index]) * feed_in_tariff[index]

          grid_costs + opportunity_costs
        else
          # It all comes from the inverter, so we don't have to pay for it,
          # but we loose the feed-in tariff
          house_power_array[index] * feed_in_tariff[index]
        end
      end
  end

  def total_costs
    return unless wallbox_costs && house_costs

    wallbox_costs + house_costs
  end

  private

  def section_sum(&)
    (
      sections.each_with_index.sum { |_section, index| yield(index) } / 1_000.0
    ).round(2)
  end
end
