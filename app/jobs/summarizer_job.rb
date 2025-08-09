class SummarizerJob < ApplicationJob # rubocop:disable Metrics/ClassLength
  queue_as :default

  def perform(date)
    @date = date

    perform_calculations
  end

  attr_reader :date

  private

  def perform_calculations
    # Build attributes outside the transaction to avoid long locks
    return unless attributes

    # If there is no summary for the given date, create it
    # Otherwise, if the existing summary is not up-to-date, update it
    ActiveRecord::Base.transaction do
      summary = Summary.where(date:).first || Summary.new(date:)

      if summary.new_record? || summary.stale?(current_tolerance: 0)
        updating = !summary.new_record?
        updating ? summary.touch : summary.save!

        # Fix main consumers and match with grid_import_power
        correct_values(:grid_import_power, *main_sensor_names_for_corrector)

        # Fix custom consumers, but without comparing with grid_import_power
        correct_values(*custom_sensor_names_for_corrector)

        save_values(updating:)
      end
    rescue ActiveRecord::RecordNotUnique
      # Race condition: Another job has created the summary in the meantime
      # We can safely ignore this error
      #
      # :nocov:
      Rails.logger.warn("Summary for #{date} already exists.")
      # :nocov:
    end
  end

  def correct_values(*sensor_names)
    corrector =
      SummaryCorrector.new(
        attributes
          .slice(*sensor_names.map { :"sum_#{it}" })
          .compact
          .transform_keys { it.to_s.delete_prefix('sum_').to_sym },
      )

    attributes.merge!(corrector.adjusted.transform_keys { :"sum_#{it}" })
  end

  def main_sensor_names_for_corrector
    power_keys =
      %i[house_power heatpump_power wallbox_power battery_charging_power] +
        SensorConfig.x.excluded_custom_sensor_names
    grid_keys = power_keys.map { :"#{it}_grid" }

    power_keys + grid_keys
  end

  def custom_sensor_names_for_corrector
    power_keys = SensorConfig.x.included_custom_sensor_names
    grid_keys = power_keys.map { |key| :"#{key}_grid" }

    power_keys + grid_keys
  end

  def save_values(updating: false)
    summary_values =
      attributes.filter_map do |attribute, value|
        aggregation, *field_parts = attribute.to_s.split('_')
        field = field_parts.join('_')

        { field:, aggregation:, value:, date: }
      end

    present_summary_values =
      summary_values.select do |record|
        should_include_record?(record[:value], record[:aggregation])
      end

    SummaryValue.upsert_all(
      present_summary_values,
      unique_by: %i[date aggregation field],
      update_only: %i[value],
    )

    return unless updating

    # Delete empty values, which may exists before (rare case)
    empty_summary_values = summary_values - present_summary_values
    query =
      empty_summary_values.reduce(nil) do |scope, attr|
        condition = SummaryValue.where(attr.slice(:date, :aggregation, :field))
        scope ? scope.or(condition) : condition
      end

    query&.delete_all
  end

  def raw_attributes
    {}.merge(raw_sum_attributes)
      .merge(raw_max_attributes)
      .merge(raw_min_attributes)
      .merge(raw_avg_attributes)
  end

  def raw_sum_attributes
    base_sensors =
      SensorConfig.x.inverter_sensor_names +
        %i[
          inverter_power_forecast
          house_power
          heatpump_power
          heatpump_heating_power
          grid_import_power
          grid_export_power
          battery_charging_power
          battery_discharging_power
          wallbox_power
        ]

    custom_sensors = SensorConfig.x.existing_custom_sensor_names

    power_splitter_sensors =
      %i[
        house_power_grid
        wallbox_power_grid
        heatpump_power_grid
        battery_charging_power_grid
      ] + custom_sensors.map { |sensor| :"#{sensor}_grid" }

    power_attributes =
      (base_sensors + custom_sensors + power_splitter_sensors).to_h do |attr|
        [:"sum_#{attr}", query_sum.public_send(attr)]
      end

    power_attributes.merge(sum_grid_costs:, sum_grid_revenue:)
  end

  def raw_max_attributes
    {
      max_battery_charging_power: query_aggregation.max_battery_charging_power,
      max_battery_discharging_power:
        query_aggregation.max_battery_discharging_power,
      max_battery_soc: query_aggregation.max_battery_soc,
      max_car_battery_soc: query_aggregation.max_car_battery_soc,
      max_case_temp: query_aggregation.max_case_temp,
      max_outdoor_temp: query_aggregation.max_outdoor_temp,
      max_grid_export_power: query_aggregation.max_grid_export_power,
      max_grid_import_power: query_aggregation.max_grid_import_power,
      max_heatpump_power: query_aggregation.max_heatpump_power,
      max_house_power: query_aggregation.max_house_power,
      **SensorConfig.x.inverter_sensor_names.to_h do |sensor|
        [:"max_#{sensor}", query_aggregation.public_send(:"max_#{sensor}")]
      end,
      max_wallbox_power: query_aggregation.max_wallbox_power,
    }
  end

  def raw_min_attributes
    {
      min_battery_soc: query_aggregation.min_battery_soc,
      min_car_battery_soc: query_aggregation.min_car_battery_soc,
      min_case_temp: query_aggregation.min_case_temp,
      min_outdoor_temp: query_aggregation.min_outdoor_temp,
    }
  end

  def raw_avg_attributes
    {
      avg_battery_soc: query_aggregation.mean_battery_soc,
      avg_car_battery_soc: query_aggregation.mean_car_battery_soc,
      avg_case_temp: query_aggregation.mean_case_temp,
      avg_outdoor_temp: query_aggregation.mean_outdoor_temp,
    }
  end

  def attributes
    @attributes ||= build_attributes
  end

  def build_attributes
    clean_attributes = raw_attributes

    # The `integral()` function in InfluxDB returns `0` when no data is available,
    # but we want to store `nil` in this case.
    #
    # We can fix this, because we have the `max` values available, which ARE
    # `nil` when no data is available
    SensorConfig::SENSOR_NAMES.each do |sensor|
      sum_attr = :"sum_#{sensor}"
      max_attr = :"max_#{sensor}"

      # Nullify sum if max is nil and both attributes are present
      clean_attributes[sum_attr] = nil if clean_attributes.key?(max_attr) &&
        clean_attributes.key?(sum_attr) && clean_attributes[max_attr].nil?
    end

    # Fix the power-splitter sums in a similar way:
    # Nullify power-splitter sums when there is no corresponding sum value
    (
      %i[house_power wallbox_power heatpump_power] +
        SensorConfig.x.existing_custom_sensor_names
    ).each do |sensor|
      grid_attr = :"sum_#{sensor}_grid"
      sum_attr = :"sum_#{sensor}"

      clean_attributes[grid_attr] = nil unless clean_attributes[sum_attr]
    end

    clean_attributes
  end

  def query_sum
    @query_sum ||= Queries::InfluxSum.new(timeframe)
  end

  def query_aggregation
    @query_aggregation ||= Queries::InfluxAggregation.new(timeframe)
  end

  def timeframe
    @timeframe ||= Timeframe.new(date.iso8601)
  end

  def sum_grid_costs
    return unless (grid_import_power = query_sum.grid_import_power)
    return if grid_import_power.zero?

    electricity_price = price_for_date(:electricity)
    return unless electricity_price

    grid_import_power * electricity_price.fdiv(1000)
  end

  def sum_grid_revenue
    return unless (grid_export_power = query_sum.grid_export_power)
    return if grid_export_power.zero?

    feed_in_price = price_for_date(:feed_in)
    return unless feed_in_price

    grid_export_power * feed_in_price.fdiv(1000)
  end

  def should_include_record?(value, aggregation)
    # For sum aggregations, filter out zero values
    # For other aggregations (max, min, avg), keep all present values
    if aggregation == 'sum'
      value&.nonzero?
    else
      value.present?
    end
  end

  def price_for_date(name)
    @prices ||= {}
    @prices[name] ||= Price
      .where(name:)
      .where(starts_at: ..date)
      .order(starts_at: :desc)
      .pick(:value)
  end
end
