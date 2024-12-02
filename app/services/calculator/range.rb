class Calculator::Range < Calculator::Base # rubocop:disable Metrics/ClassLength
  def initialize(timeframe, calculations:)
    super()

    @timeframe = timeframe
    @calculations = calculations

    data = sections
    if timeframe.starts_today?
      # Because the Power-Splitter runs not in real-time, we need to correct the
      # *_power_grid values, so their total matches grid_import_power
      data.each do |entry|
        corrector =
          Calculator::PowerSplitterCorrector.new(
            grid_import_power: entry[:grid_import_power],
            house_power: entry[:house_power],
            house_power_grid: entry[:house_power_grid],
            heatpump_power: entry[:heatpump_power],
            heatpump_power_grid: entry[:heatpump_power_grid],
            wallbox_power: entry[:wallbox_power],
            wallbox_power_grid: entry[:wallbox_power_grid],
          )

        entry[:house_power_grid] = corrector.adjusted_house_power_grid
        entry[:wallbox_power_grid] = corrector.adjusted_wallbox_power_grid
        entry[:heatpump_power_grid] = corrector.adjusted_heatpump_power_grid
      end
    end

    build_context(data)
  end

  attr_reader :timeframe, :calculations

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

    build_method_from_array(:heatpump_heating_power, data, :to_f)
    build_method_from_array(:car_driving_distance, data, :to_f)

    (1..10).each do |index|
      build_method_from_array(:"custom_#{format('%02d', index)}_power", data)
    end

    build_method(:outdoor_temp, global) if calculations.key?(:outdoor_temp)
    build_method(:heatpump_score, global) if calculations.key?(:heatpump_score)

    return unless timeframe.day?

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

  def self_consumption
    return unless inverter_power && grid_export_power

    inverter_power - grid_export_power
  end

  def opportunity_costs
    section_sum do |index|
      (inverter_power_array[index] - grid_export_power_array[index]) *
        feed_in_tariff_array[index]
    end
  end

  def total_costs
    paid.abs + opportunity_costs.abs
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

  def electricity_prices
    @electricity_prices ||= sections.pluck(:electricity_price).sort
  end

  def feed_in_tariffs
    @feed_in_tariffs ||= sections.pluck(:feed_in_tariff).sort
  end

  # Wallbox

  def wallbox_power_grid_ratio
    return unless wallbox_power_grid

    if wallbox_power.zero?
      0
    else
      (wallbox_power_grid.fdiv(wallbox_power) * 100).round.clamp(0, 100)
    end
  end

  def wallbox_power_pv_ratio
    return unless wallbox_power_grid_ratio

    100 - wallbox_power_grid_ratio
  end

  def wallbox_costs_grid
    return unless wallbox_power_grid

    sections.each_with_index.sum do |section, index|
      wallbox_power_grid_array[index].to_f * section[:electricity_price] / 1000
    end
  end

  def wallbox_costs_pv
    return unless wallbox_power_grid_ratio

    sections.each_with_index.sum do |section, index|
      (wallbox_power_array[index] - wallbox_power_grid_array[index].to_f) *
        section[:feed_in_tariff] / 1000
    end
  end

  def wallbox_costs
    return unless wallbox_costs_grid && wallbox_costs_pv

    wallbox_costs_grid + wallbox_costs_pv
  end

  # Car

  def wallbox_power_per_100km
    return unless car_driving_distance&.nonzero? && wallbox_power

    wallbox_power.fdiv(car_driving_distance) * 100
  end

  def wallbox_costs_per_100km
    return unless car_driving_distance&.nonzero? && wallbox_costs

    wallbox_costs.fdiv(car_driving_distance) * 100
  end

  # Heat pump

  def heatpump_power_pv
    return unless heatpump_power && heatpump_power_grid

    heatpump_power - heatpump_power_grid
  end

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

  def heatpump_costs_grid
    return unless heatpump_power_grid_ratio

    sections.each_with_index.sum do |section, index|
      heatpump_power_grid_array[index].to_f * section[:electricity_price] / 1000
    end
  end

  def heatpump_costs_pv
    return unless heatpump_power_grid_ratio
    return 0 unless Setting.opportunity_costs

    sections.each_with_index.sum do |section, index|
      (heatpump_power_array[index] - heatpump_power_grid_array[index].to_f) *
        section[:feed_in_tariff] / 1000
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

  def house_costs_grid
    return unless house_power_grid_ratio

    sections.each_with_index.sum do |section, index|
      house_power_grid_array[index].to_f * section[:electricity_price] / 1000
    end
  end

  def house_costs_pv
    return unless house_power_grid_ratio

    sections.each_with_index.sum do |section, index|
      (house_power_array[index] - house_power_grid_array[index].to_f) *
        section[:feed_in_tariff] / 1000
    end
  end

  def house_costs
    return unless house_costs_grid && house_costs_pv

    house_costs_grid + house_costs_pv
  end

  def house_without_custom_costs
    house_power_without_custom / house_power * house_costs
  end

  (1..10).each do |index|
    define_method format('custom_%02d_costs', index) do
      custom_power(index).to_f / house_power * house_costs
    end
  end

  private

  def price_sections
    DateInterval.new(
      starts_at: timeframe.effective_beginning_date,
      ends_at: timeframe.ending.to_date,
    ).price_sections
  end

  def query(from:, to:, selected_calculations:)
    Calculator::QuerySql.new(from:, to:, calculations: selected_calculations)
  end

  def avg_calculations
    @avg_calculations ||=
      calculations.select { |_sensor, value| value.to_s.start_with?('avg_') }
  end

  def sum_calculations
    @sum_calculations ||=
      calculations.select { |_sensor, value| value.to_s.start_with?('sum_') }
  end

  def global
    return if avg_calculations.blank?

    @global ||=
      begin
        summary =
          query(
            from: timeframe.effective_beginning_date,
            to: timeframe.ending,
            selected_calculations: avg_calculations.values,
          )

        avg_calculations
          .keys
          .index_with { |sensor| summary.public_send(avg_calculations[sensor]) }
          .merge(time: summary.time)
      end
  end

  def sections
    return if sum_calculations.blank?

    @sections ||=
      price_sections.map do |price_section|
        summary =
          query(
            from: price_section[:starts_at],
            to: price_section[:ends_at],
            selected_calculations: sum_calculations.values,
          )

        sum_calculations
          .keys
          .index_with { |sensor| summary.public_send(sum_calculations[sensor]) }
          .merge(
            time: summary.time,
            electricity_price: price_section[:electricity],
            feed_in_tariff: price_section[:feed_in],
          )
      end
  end

  def section_sum(&)
    (
      sections.each_with_index.sum { |_section, index| yield(index) } / 1_000.0
    ).round(2)
  end
end
