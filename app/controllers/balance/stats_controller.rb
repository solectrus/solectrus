class Balance::StatsController < ApplicationController
  include ParamsHandling
  include TimeframeNavigation

  before_action :refresh_summaries_if_needed

  def index
    if turbo_frame_request?
      # Request comes from a single TurboFrame, but we want to update multiple other frames, too
      render formats: :turbo_stream
    else
      # Fallback
      redirect_to balance_home_path(sensor_name: sensor.name, timeframe:)
    end
  end

  private

  def refresh_summaries_if_needed
    return if timeframe.now? || timeframe.hours?

    # In most cases, stale summaries are not possible when we get here, because this was
    # already checked in HomeController#index. But there is one exception: when the
    # user comes back to the page without navigation, then the JS reloads the frames
    # directly, without going through HomeController#index.
    Sensor::Summarizer.call(timeframe)
  end

  def data_now
    sensors = %i[
      autarky
      battery_charging_power
      battery_discharging_power
      battery_soc
      car_battery_soc
      case_temp
      grid_export_limit
      grid_export_power
      grid_import_power
      grid_quote
      heatpump_power
      house_power
      inverter_power
      self_consumption_quote
      system_status
      system_status_ok
      wallbox_car_connected
      wallbox_power
    ]

    unless Setting.inverter_as_total
      sensors.concat(
        [:inverter_power_total] +
          Sensor::Config.custom_inverter_sensors.map(&:name),
      )
    end

    PowerBalance.new(Sensor::Query::Latest.new(sensors).call)
  end

  def data_range # rubocop:disable Metrics/AbcSize
    data =
      Sensor::Query::Total
        .new(timeframe) do |q|
          q.avg :autarky, :avg
          q.sum :battery_charging_costs, :sum
          q.sum :battery_charging_power, :sum
          q.sum :battery_charging_power_grid, :sum
          q.sum :battery_discharging_power, :sum
          q.sum :co2_reduction, :sum
          q.sum :grid_costs, :sum
          q.sum :grid_export_power, :sum
          q.sum :grid_import_power, :sum
          q.avg :grid_quote, :avg
          q.sum :grid_revenue, :sum
          q.sum :heatpump_costs, :sum
          q.sum :heatpump_power, :sum
          q.sum :heatpump_power_grid, :sum
          q.sum :house_costs, :sum
          q.sum :house_power, :sum
          q.sum :house_power_grid, :sum
          q.sum :savings, :sum
          q.sum :battery_savings, :sum
          q.avg :self_consumption_quote, :avg
          q.sum :solar_price, :sum
          q.sum :total_costs, :sum
          q.sum :traditional_costs, :sum
          q.sum :wallbox_costs, :sum
          q.sum :wallbox_power, :sum
          q.sum :wallbox_power_grid, :sum

          q.sum :inverter_power, :sum
          Sensor::Config.custom_inverter_sensors.each do |sensor|
            q.sum sensor.name, :sum
          end

          unless Setting.inverter_as_total
            q.sum :inverter_power_total, :sum
            q.sum :inverter_power_difference, :sum
          end

          Sensor::Config.house_power_excluded_custom_sensors.each do |sensor|
            q.sum sensor.name, :sum
            q.sum :"#{sensor.name.to_s.gsub('_power', '')}_costs", :sum
          end
        end
        .call

    PowerBalance.new(data)
  end
end
