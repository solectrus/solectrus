class Calculator::Range < Calculator::Base
  CO2_EMISION_FACTOR = 401 # g / kWh
  public_constant :CO2_EMISION_FACTOR

  def initialize(timeframe)
    super()

    @timeframe = timeframe

    build_context PowerSum.new(
                    measurements: [
                      Rails.configuration.x.influx.measurement_pv,
                      Rails.configuration.x.influx.measurement_forecast,
                    ],
                    fields:,
                  ).call(timeframe)
  end

  def fields
    result = %i[
      inverter_power
      house_power
      wallbox_charge_power
      grid_power_plus
      grid_power_minus
      bat_power_minus
      bat_power_plus
    ]

    # Include forecast for days only
    result << :watt if @timeframe.day?

    result
  end

  def build_context(data)
    build_method(:sections) { data }
    build_method(:time) { data.pluck(:time).last }

    build_method_from_array(:feed_in_tariff, data)
    build_method_from_array(:electricity_price, data)

    build_method_from_array(:inverter_power, data)
    build_method_from_array(:house_power, data)
    build_method_from_array(:wallbox_charge_power, data)
    build_method_from_array(:grid_power_plus, data)
    build_method_from_array(:grid_power_minus, data)
    build_method_from_array(:bat_power_minus, data)
    build_method_from_array(:bat_power_plus, data)
    build_method_from_array(:watt, data) if @timeframe.day?
  end

  def forecast_deviation
    return unless respond_to?(:watt)
    return if watt.zero?

    ((inverter_power * 100.0 / watt) - 100).round
  end

  def paid
    return unless grid_power_plus

    -section_sum do |index|
      grid_power_plus_array[index] * electricity_price_array[index]
    end
  end

  def got
    return unless grid_power_minus

    section_sum do |index|
      grid_power_minus_array[index] * feed_in_tariff_array[index]
    end
  end

  def solar_price
    return unless got && paid

    got + paid
  end

  def traditional_price
    return unless consumption

    -section_sum do |index|
      consumption_array[index] * electricity_price_array[index]
    end
  end

  def savings
    return unless solar_price && traditional_price

    solar_price - traditional_price
  end

  def co2_savings
    return unless inverter_power

    inverter_power / 1000 * CO2_EMISION_FACTOR
  end

  def battery_savings
    return unless bat_power_minus && bat_power_plus && savings

    [
      section_sum do |index|
        (bat_power_minus_array[index] * electricity_price_array[index]) -
          (bat_power_plus_array[index] * feed_in_tariff_array[index])
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
        [wallbox_charge_power_array[index], grid_power_plus_array[index]].min *
          electricity_price_array[index]
      end
  end

  def house_costs
    return unless house_power

    @house_costs ||=
      -section_sum do |index|
        total_costs =
          (grid_power_plus_array[index] * electricity_price_array[index])

        wallbox_costs =
          [
            wallbox_charge_power_array[index],
            grid_power_plus_array[index],
          ].min * electricity_price_array[index]

        total_costs - wallbox_costs
      end
  end

  def electricity_prices
    @electricity_prices ||= sections.pluck(:electricity_price).sort
  end

  private

  def section_sum(&)
    (
      sections.each_with_index.sum { |_section, index| yield(index) } / 1_000.0
    ).round(2)
  end
end
