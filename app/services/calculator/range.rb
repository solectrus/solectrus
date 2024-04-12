class Calculator::Range < Calculator::Base # rubocop:disable Metrics/ClassLength
  def initialize(timeframe)
    super()

    @timeframe = timeframe

    build_context PowerSum.new(sensors:).call(timeframe)
  end

  def sensors
    result = %i[
      inverter_power
      house_power
      wallbox_power
      grid_import_power
      grid_export_power
      battery_discharging_power
      battery_charging_power
      heatpump_power
    ]

    %i[house_power_grid wallbox_power_grid heatpump_power_grid].each do |sensor|
      result << sensor if SensorConfig.x.exists?(sensor)
    end

    # Include forecast for days only
    result << :inverter_power_forecast if @timeframe.day?

    result
  end

  def build_context(data)
    build_method(:sections) { data }
    build_method(:time) { data.pluck(:time).last }

    build_method_from_array(:feed_in_tariff, data, :to_f)
    build_method_from_array(:electricity_price, data, :to_f)

    build_method_from_array(:inverter_power, data, :to_f)
    build_house_power_from_array(data)
    build_method_from_array(:wallbox_power, data, :to_f)
    build_method_from_array(:grid_import_power, data, :to_f)
    build_method_from_array(:grid_export_power, data, :to_f)
    build_method_from_array(:battery_discharging_power, data, :to_f)
    build_method_from_array(:battery_charging_power, data, :to_f)
    build_method_from_array(:heatpump_power, data, :to_f)

    build_method_from_array(:house_power_grid, data)
    build_method_from_array(:wallbox_power_grid, data)
    build_method_from_array(:heatpump_power_grid, data)

    return unless @timeframe.day?

    build_method_from_array(:inverter_power_forecast, data, :to_f)
  end

  def build_house_power_from_array(data)
    values =
      data.map do |value|
        [
          SensorConfig
            .x
            .exclude_from_house_power
            .reduce(value[:house_power].to_f) do |acc, elem|
              acc - value[elem].to_f
            end,
          0,
        ].max
      end

    build_method('house_power_array') { values }
    build_method(:house_power) { values.sum }
  end

  def forecast_deviation
    return unless respond_to?(:inverter_power_forecast)
    return if inverter_power_forecast.zero?

    ((inverter_power * 100.0 / inverter_power_forecast) - 100).round
  end

  def paid
    return unless grid_import_power

    -section_sum do |index|
      grid_import_power_array[index] * electricity_price_array[index]
    end
  end

  def got
    return unless grid_export_power

    section_sum do |index|
      grid_export_power_array[index] * feed_in_tariff_array[index]
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

  def co2_reduction
    return unless inverter_power

    inverter_power / 1000 * Rails.application.config.x.co2_emission_factor
  end

  def battery_savings
    return unless battery_discharging_power && battery_charging_power && savings

    [
      section_sum do |index|
        (
          battery_discharging_power_array[index] *
            electricity_price_array[index]
        ) - (battery_charging_power_array[index] * feed_in_tariff_array[index])
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
    return unless wallbox_power && grid_import_power

    @wallbox_costs ||=
      -section_sum do |index|
        [wallbox_power_array[index], grid_import_power_array[index]].min *
          electricity_price_array[index]
      end
  end

  def house_costs
    return unless house_power

    @house_costs ||=
      -section_sum do |index|
        total_costs =
          (grid_import_power_array[index] * electricity_price_array[index])

        wallbox_costs =
          [wallbox_power_array[index], grid_import_power_array[index]].min *
            electricity_price_array[index]

        total_costs - wallbox_costs
      end
  end

  def electricity_prices
    @electricity_prices ||= sections.pluck(:electricity_price).sort
  end

  # Total

  def total_power
    wallbox_power + heatpump_power + house_power
  end

  def total_power_pv
    wallbox_power_pv + heatpump_power_pv + house_power_pv
  end

  def total_power_grid
    return unless wallbox_power_grid || heatpump_power_grid || house_power_grid

    wallbox_power_grid.to_i + heatpump_power_grid.to_i + house_power_grid.to_i
  end

  def total_power_grid_ratio
    if total_power.zero?
      0
    else
      (total_power_grid.fdiv(total_power) * 100).round.clamp(0, 100)
    end
  end

  def total_power_pv_ratio
    100 - total_power_grid_ratio
  end

  def total_costs_ratio
    (total_costs.fdiv(max_costs) * 100).round
  end

  def total_costs_grid
    wallbox_costs_grid + heatpump_costs_grid + house_costs_grid
  end

  def total_costs_pv
    wallbox_costs_pv + heatpump_costs_pv + house_costs_pv
  end

  def total_costs
    wallbox_costs + heatpump_costs + house_costs
  end

  # Wallbox

  def wallbox_power_pv
    wallbox_power - wallbox_power_grid
  end

  def wallbox_power_grid_ratio
    if wallbox_power.zero?
      0
    else
      (wallbox_power_grid.fdiv(wallbox_power) * 100).round.clamp(0, 100)
    end
  end

  def wallbox_power_pv_ratio
    100 - wallbox_power_grid_ratio
  end

  def wallbox_costs_ratio
    (wallbox_costs.fdiv(max_costs) * 100).round
  end

  def wallbox_costs_grid
    return unless wallbox_power_grid_array.all?(&:present?)

    sections.each_with_index.sum do |section, index|
      wallbox_power_grid_array[index] / 1000 * section[:electricity_price]
    end
  end

  def wallbox_costs_pv
    return unless wallbox_power_grid_array.all?(&:present?)

    sections.each_with_index.sum do |section, index|
      (wallbox_power_array[index] - wallbox_power_grid_array[index]) / 1000 *
        section[:feed_in_tariff]
    end
  end

  def wallbox_costs
    wallbox_costs_grid + wallbox_costs_pv
  end

  # Heat pump

  def heatpump_power_grid_ratio
    return unless heatpump_power_grid

    if heatpump_power.zero?
      0
    else
      (heatpump_power_grid.fdiv(heatpump_power) * 100).round.clamp(0, 100)
    end
  end

  def heatpump_power_pv_ratio
    return unless heatpump_power_grid_ratio

    100 - heatpump_power_grid_ratio
  end

  def heatpump_costs_ratio
    return unless heatpump_costs

    (heatpump_costs.fdiv(max_costs) * 100).round
  end

  def heatpump_costs_grid
    return unless heatpump_power_grid_array.all?(&:present?)

    sections.each_with_index.sum do |section, index|
      heatpump_power_grid_array[index] / 1000 * section[:electricity_price]
    end
  end

  def heatpump_costs_pv
    return unless heatpump_power_grid_array.all?(&:present?)

    sections.each_with_index.sum do |section, index|
      (heatpump_power_array[index] - heatpump_power_grid_array[index]) / 1000 *
        section[:feed_in_tariff]
    end
  end

  def heatpump_costs
    return unless heatpump_costs_grid && heatpump_costs_pv

    heatpump_costs_grid + heatpump_costs_pv
  end

  # House Power

  def house_power_grid_ratio
    return unless house_power_grid

    if house_power.zero?
      0
    else
      (house_power_grid.fdiv(house_power) * 100).round.clamp(0, 100)
    end
  end

  def house_power_pv_ratio
    return unless house_power_grid_ratio

    100 - house_power_grid_ratio
  end

  def house_costs_ratio
    return unless house_costs

    (house_costs.fdiv(max_costs) * 100).round
  end

  def house_costs_grid
    return unless house_power_grid_array.all?(&:present?)

    sections.each_with_index.sum do |section, index|
      house_power_grid_array[index] / 1000 * section[:electricity_price]
    end
  end

  def house_costs_pv
    return unless house_power_grid_array.all?(&:present?)

    sections.each_with_index.sum do |section, index|
      (house_power_array[index] - house_power_grid_array[index]) / 1000 *
        section[:feed_in_tariff]
    end
  end

  def house_costs
    return unless house_costs_grid && house_costs_pv

    house_costs_grid + house_costs_pv
  end

  private

  def section_sum(&)
    (
      sections.each_with_index.sum { |_section, index| yield(index) } / 1_000.0
    ).round(2)
  end
end
