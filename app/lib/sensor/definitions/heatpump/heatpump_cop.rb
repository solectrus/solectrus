class Sensor::Definitions::HeatpumpCop < Sensor::Definitions::Base
  value unit: :unitless, category: :heatpump

  color hex: '#0369a1',
        bg_classes: 'bg-sky-700 dark:bg-sky-700',
        text_classes: 'text-sky-200 dark:text-sky-400'

  depends_on :heatpump_power, :heatpump_heating_power

  calculate do |heatpump_power:, heatpump_heating_power:, **|
    return unless heatpump_heating_power
    return if heatpump_power.nil? || heatpump_power.zero?

    heatpump_heating_power.fdiv(heatpump_power).round(2)
  end

  aggregations stored: false, computed: [:avg], meta: [:avg], top10: true

  trend aggregation: :avg, more_is_better: true

  chart do |timeframe|
    Sensor::Chart::HeatpumpCop.new(timeframe:)
  end

  def sql_calculation
    # COP = heating power / electrical power
    # Use NULLIF to avoid division by zero
    'COALESCE(heatpump_heating_power_sum, 0) / NULLIF(COALESCE(heatpump_power_sum, 0), 0)'
  end

  # For period aggregations (week/month/year), we need to sum the components first,
  # then calculate the ratio, instead of averaging daily COPs
  def sql_calculation_period
    'SUM(COALESCE(heatpump_heating_power_sum, 0)) / NULLIF(SUM(COALESCE(heatpump_power_sum, 0)), 0)'
  end

  requires_permission :heatpump
end
