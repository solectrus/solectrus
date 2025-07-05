class Calculator::Range < Calculator::Base # rubocop:disable Metrics/ClassLength
  def initialize(timeframe, calculations: nil)
    super()

    @timeframe = timeframe
    @calculations = calculations || default_calculations
    data = sections

    build_context(data)
  end

  attr_reader :timeframe, :calculations

  def default_calculations
    [
      *SensorConfig.x.inverter_sensor_names.map do |sensor_name|
        Queries::Calculation.new(sensor_name, :sum, :sum)
      end,
      Queries::Calculation.new(:house_power, :sum, :sum),
      Queries::Calculation.new(:wallbox_power, :sum, :sum),
      Queries::Calculation.new(:grid_import_power, :sum, :sum),
      Queries::Calculation.new(:grid_export_power, :sum, :sum),
      Queries::Calculation.new(:battery_discharging_power, :sum, :sum),
      Queries::Calculation.new(:battery_charging_power, :sum, :sum),
      Queries::Calculation.new(:heatpump_power, :sum, :sum),
      # --- Power splitter ----
      Queries::Calculation.new(:house_power_grid, :sum, :sum),
      Queries::Calculation.new(:wallbox_power_grid, :sum, :sum),
      Queries::Calculation.new(:heatpump_power_grid, :sum, :sum),
      Queries::Calculation.new(:battery_charging_power_grid, :sum, :sum),
    ]
  end

  # Build dynamic methods based on sections data
  def build_context(data)
    build_method(:sections) { data }

    # Methods with float conversion
    (
      SensorConfig.x.inverter_sensor_names +
        %i[
          feed_in_tariff
          electricity_price
          wallbox_power
          grid_import_power
          grid_export_power
          battery_discharging_power
          battery_charging_power
          heatpump_power
        ]
    ).each { |name| build_method_from_array(name, data, :to_f) }

    build_house_power_from_array(data)
    build_inverter_power_from_array(data)

    # Methods without conversion
    %i[
      house_power_grid
      wallbox_power_grid
      heatpump_power_grid
      battery_charging_power_grid
    ].each { |name| build_method_from_array(name, data) }

    # Build methods for custom sensors
    SensorConfig.x.existing_custom_sensor_names.each do |sensor_name|
      build_method_from_array(sensor_name, data)
      build_method_from_array(:"#{sensor_name}_grid", data)
    end

    return unless timeframe.day?

    build_method_from_array(:inverter_power_forecast, data, :to_f)
  end

  # Builds house power methods subtracting excluded sensors
  def build_house_power_from_array(data)
    values =
      data.map do |value|
        [
          SensorConfig
            .x
            .excluded_sensor_names
            .reduce(value[:house_power].to_f) do |acc, elem|
              acc - value[elem].to_f
            end,
          0,
        ].max
      end

    build_method('house_power_array') { values }
    build_method(:house_power) { values.sum }
  end

  def build_inverter_power_from_array(data)
    values =
      if SensorConfig.x.multi_inverter?
        data.map do |value|
          value[:inverter_power] ||
            SensorConfig::CUSTOM_INVERTER_SENSORS
              .filter_map { |key| value[key] }
              .sum
        end
      else
        data.map { |value| value[:inverter_power].to_f }
      end

    build_method('inverter_power_array') { values }
    build_method(:inverter_power) { values.sum }
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

  def consumption_array
    sections.each_with_index.map do |_section, index|
      house_power_array[index] + wallbox_power_array[index] +
        heatpump_power_array[index] +
        SensorConfig.x.excluded_custom_sensor_names.sum do |sensor_name|
          public_send(:"#{sensor_name}_array")[index] || 0
        end
    end
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

  def battery_charging_power_grid_ratio
    return unless battery_charging_power_grid

    calculate_ratio(battery_charging_power_grid, battery_charging_power)
  end

  def battery_charging_power_pv_ratio
    return unless battery_charging_power_grid_ratio

    100 - battery_charging_power_grid_ratio
  end

  def battery_charging_costs
    return unless battery_charging_power_grid_ratio

    sections.each_with_index.sum do |section, index|
      battery_charging_power_grid_array[index].to_f *
        section[:electricity_price] / 1000
    end
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

    calculate_ratio(wallbox_power_grid, wallbox_power)
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
    return 0 unless Setting.opportunity_costs

    sections.each_with_index.sum do |section, index|
      (wallbox_power_array[index] - wallbox_power_grid_array[index].to_f) *
        section[:feed_in_tariff] / 1000
    end
  end

  def wallbox_costs
    return unless wallbox_costs_grid && wallbox_costs_pv

    wallbox_costs_grid + wallbox_costs_pv
  end

  # Heat pump

  def heatpump_power_grid_ratio
    return unless heatpump_power_grid

    calculate_ratio(heatpump_power_grid, heatpump_power)
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
    unless house_power_grid
      return SensorConfig.x.single_consumer? ? grid_quote : nil
    end

    return 0 if house_power.zero?

    calculate_ratio(house_power_grid, house_power)
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
    return 0 unless Setting.opportunity_costs

    sections.each_with_index.sum do |section, index|
      (house_power_array[index] - house_power_grid_array[index].to_f) *
        section[:feed_in_tariff] / 1000
    end
  end

  def house_costs
    if SensorConfig.x.single_consumer?
      Setting.opportunity_costs ? total_costs : paid.abs
    else
      return unless house_costs_grid && house_costs_pv

      house_costs_grid + house_costs_pv
    end
  end

  def house_power_without_custom_grid_ratio
    unless house_power_grid
      return SensorConfig.x.single_consumer? ? grid_quote : nil
    end
    return unless house_power_without_custom&.nonzero?

    house_power_without_custom_grid.fdiv(house_power_without_custom) * 100
  end

  def house_without_custom_costs
    unless house_power_without_custom && house_costs && house_power&.nonzero?
      return
    end

    house_power_without_custom / house_power * house_costs
  end

  # Dynamic custom sensor methods
  SensorConfig::CUSTOM_SENSORS.each do |sensor_name|
    base = sensor_name.to_s.sub('_power', '')

    define_method(:"#{base}_costs_grid") do # def custom_01_costs_grid
      grid_array = public_send(:"#{sensor_name}_grid_array")

      sections.each_with_index.sum do |section, index|
        grid_array[index].to_f * section[:electricity_price] / 1000
      end
    end

    define_method(:"#{base}_costs_pv") do # def custom_01_costs_pv
      return 0 unless Setting.opportunity_costs

      grid_ratio = public_send(:"#{sensor_name}_grid_ratio")
      return unless grid_ratio

      array = public_send(:"#{sensor_name}_array")
      grid_array = public_send(:"#{sensor_name}_grid_array")

      sections.each_with_index.sum do |section, index|
        (array[index].to_f - grid_array[index].to_f) *
          section[:feed_in_tariff].fdiv(1000)
      end
    end

    define_method(:"#{base}_costs") do # def custom_01_costs
      costs_grid = public_send(:"#{base}_costs_grid")
      costs_pv = public_send(:"#{base}_costs_pv")
      return unless costs_grid && costs_pv

      costs_grid + costs_pv
    end

    define_method(:"#{sensor_name}_grid_ratio") do # def custom_01_grid_ratio
      custom_power_grid = safe_grid_power_value(sensor_name)
      return unless custom_power_grid

      custom_power = safe_power_value(sensor_name)
      custom_power.zero? ? 0 : custom_power_grid.fdiv(custom_power) * 100
    end
  end

  def custom_power_grid_total
    @custom_power_grid_total ||=
      SensorConfig.x.included_custom_sensor_names.sum do |sensor_name|
        safe_grid_power_value(sensor_name)
      end
  end

  def house_power_without_custom_grid
    (house_power_grid - custom_power_grid_total).clamp(
      0,
      house_power_without_custom,
    )
  end

  def time
    return if timeframe.past?

    @time ||=
      Summary
        .where(date: ..timeframe.effective_ending_date)
        .order(date: :desc)
        .limit(1)
        .pick(:updated_at)
  end

  def per_day(value)
    return unless value

    (value / timeframe.days_passed).round(2)
  end

  private

  def calculate_ratio(grid_value, power_value)
    if power_value.zero?
      0
    else
      (grid_value.fdiv(power_value) * 100).round.clamp(0, 100)
    end
  end

  def price_sections
    DateInterval.new(
      starts_at: timeframe.effective_beginning_date,
      ends_at: timeframe.ending.to_date,
    ).price_sections
  end

  def sum_calculations
    @sum_calculations ||= calculations.select { it.meta_aggregation == :sum }
  end

  def sections
    return if sum_calculations.blank?

    @sections ||=
      price_sections.map do |price_section|
        query =
          if timeframe.hours?
            Queries::InfluxSum.new(timeframe)
          else
            Queries::Sql.new(
              sum_calculations,
              from: price_section[:starts_at],
              to: price_section[:ends_at],
            )
          end

        query
          .to_hash
          .transform_keys { |field, _aggregation, _meta| field }
          .merge(
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

  def safe_grid_power_value(sensor_name)
    public_send(:"#{sensor_name}_grid") || 0
  end
end
