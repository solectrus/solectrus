class SummarizerJob < ApplicationJob
  queue_as :default

  def perform(date)
    @date = date

    perform_calculations
  end

  attr_reader :date

  private

  def perform_calculations
    # If there is no summary for the given date, create it
    # Otherwise, if the existing summary is not up-to-date, update it
    ActiveRecord::Base.transaction do
      summary = Summary.select(:date, :updated_at).find_or_initialize_by(date:)

      if summary.new_record? || summary.stale?(current_tolerance: 0)
        summary.update!(attributes)
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

  def raw_attributes
    { date: }.merge(raw_sum_attributes)
      .merge(raw_max_attributes)
      .merge(raw_min_attributes)
      .merge(raw_avg_attributes)
  end

  def raw_sum_attributes
    base_sensors = %i[
      inverter_power
      inverter_power_forecast
      house_power
      heatpump_power
      grid_import_power
      grid_export_power
      battery_charging_power
      battery_discharging_power
      wallbox_power
    ]

    custom_sensors = SensorConfig.x.existing_custom_sensor_names

    power_splitter_sensors = %i[
      house_power_grid
      wallbox_power_grid
      heatpump_power_grid
      battery_charging_power_grid
    ]

    (base_sensors + custom_sensors + power_splitter_sensors).to_h do |attr|
      [:"sum_#{attr}", query_sum.public_send(attr)]
    end
  end

  def raw_max_attributes
    {
      max_battery_charging_power: query_aggregation.max_battery_charging_power,
      max_battery_discharging_power:
        query_aggregation.max_battery_discharging_power,
      max_battery_soc: query_aggregation.max_battery_soc,
      max_car_battery_soc: query_aggregation.max_car_battery_soc,
      max_case_temp: query_aggregation.max_case_temp,
      max_grid_export_power: query_aggregation.max_grid_export_power,
      max_grid_import_power: query_aggregation.max_grid_import_power,
      max_heatpump_power: query_aggregation.max_heatpump_power,
      max_house_power: query_aggregation.max_house_power,
      max_inverter_power: query_aggregation.max_inverter_power,
      max_wallbox_power: query_aggregation.max_wallbox_power,
    }
  end

  def raw_min_attributes
    {
      min_battery_soc: query_aggregation.min_battery_soc,
      min_car_battery_soc: query_aggregation.min_car_battery_soc,
      min_case_temp: query_aggregation.min_case_temp,
    }
  end

  def raw_avg_attributes
    {
      avg_battery_soc: query_aggregation.mean_battery_soc,
      avg_car_battery_soc: query_aggregation.mean_car_battery_soc,
      avg_case_temp: query_aggregation.mean_case_temp,
    }
  end

  def attributes
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
    %i[house_power wallbox_power heatpump_power].each do |sensor|
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
end
