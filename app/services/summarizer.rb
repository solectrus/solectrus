class Summarizer
  def self.perform!(from: nil, to: nil, &)
    from = [from, Rails.configuration.x.installation_date].compact.max
    to = [to, Date.current].compact.min

    raise ArgumentError, 'from must be before to' if to < from

    # Fetch the records that need to be processed
    records_to_process = records_to_update(from:, to:)

    # Iterate over the records to process, but in reverse order, so that the
    # most recent records are processed first
    total_days = records_to_process.size
    records_to_process
      .reverse
      .each
      .with_index(1) do |date, index|
        # This can be used to track the progress of the summarizer
        yield(index, total_days) if block_given?

        # Process the record for the given date
        new(date).perform!
      end

    # Return the number of processed days
    total_days
  end

  def self.records_to_update(from:, to:)
    # Query for summaries that either do not exist
    existing_dates = Summary.where(date: from..to).pluck(:date)

    # Find missing records
    date_range = (from..to).to_a
    missing_records = date_range - existing_dates

    # Find outdated records where updated_at (as a date) is not strictly greater than the date
    outdated_records =
      Summary
        .where(date: from..to)
        .where('DATE(updated_at) <= date')
        .pluck(:date)

    # Combine missing and outdated records
    missing_records + outdated_records
  end

  def initialize(date)
    @date = date
  end

  attr_reader :date

  def perform!
    # If there is no summary for the given date, create it
    # Otherwise, if the existing summary is not up-to-date, update it
    ActiveRecord::Base.transaction do
      summary = Summary.select(:date, :updated_at).find_or_initialize_by(date:)

      if summary.new_record? || summary.updated_at.to_date <= date
        summary.update!(attributes)
      end
    end
  end

  private

  def raw_attributes # rubocop:disable Metrics/AbcSize
    {
      date:,
      # Sum
      sum_inverter_power: calculator_sum.inverter_power,
      sum_inverter_power_forecast: calculator_sum.inverter_power_forecast,
      sum_house_power: calculator_sum.house_power,
      sum_heatpump_power: calculator_sum.heatpump_power,
      sum_grid_import_power: calculator_sum.grid_import_power,
      sum_grid_export_power: calculator_sum.grid_export_power,
      sum_battery_charging_power: calculator_sum.battery_charging_power,
      sum_battery_discharging_power: calculator_sum.battery_discharging_power,
      sum_wallbox_power: calculator_sum.wallbox_power,
      # Sum Power-Splitter
      sum_house_power_grid: calculator_sum.house_power_grid,
      sum_wallbox_power_grid: calculator_sum.wallbox_power_grid,
      sum_heatpump_power_grid: calculator_sum.heatpump_power_grid,
      # Max
      max_battery_charging_power:
        calculator_aggregation.max_battery_charging_power,
      max_battery_discharging_power:
        calculator_aggregation.max_battery_discharging_power,
      max_battery_soc: calculator_aggregation.max_battery_soc,
      max_car_battery_soc: calculator_aggregation.max_car_battery_soc,
      max_case_temp: calculator_aggregation.max_case_temp,
      max_grid_export_power: calculator_aggregation.max_grid_export_power,
      max_grid_import_power: calculator_aggregation.max_grid_import_power,
      max_heatpump_power: calculator_aggregation.max_heatpump_power,
      max_house_power: calculator_aggregation.max_house_power,
      max_inverter_power: calculator_aggregation.max_inverter_power,
      max_wallbox_power: calculator_aggregation.max_wallbox_power,
      # Min
      min_battery_soc: calculator_aggregation.min_battery_soc,
      min_car_battery_soc: calculator_aggregation.min_car_battery_soc,
      min_case_temp: calculator_aggregation.min_case_temp,
      # Avg
      avg_battery_soc: calculator_aggregation.mean_battery_soc,
      avg_car_battery_soc: calculator_aggregation.mean_car_battery_soc,
      avg_case_temp: calculator_aggregation.mean_case_temp,
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

  def calculator_sum
    @calculator_sum ||= Calculator::QueryInfluxSum.new(timeframe)
  end

  def calculator_aggregation
    @calculator_aggregation ||=
      Calculator::QueryInfluxAggregation.new(timeframe:)
  end

  def timeframe
    @timeframe ||= Timeframe.new(date.iso8601)
  end
end
