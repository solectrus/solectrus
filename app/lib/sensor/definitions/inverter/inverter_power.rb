class Sensor::Definitions::InverterPower < Sensor::Definitions::Base
  value unit: :watt, range: (0..), category: :inverter

  color background: 'bg-sensor-pv',
        text: 'text-white dark:text-slate-400'

  icon 'fa-sun'

  # A measured inverter_power needs nothing; anything else is the sum of the
  # single inverters.
  #
  # A summary already holds that sum, so a SQL query reads its own field first.
  # It falls back to the single inverters only if that field is empty.
  #
  # Summing them instead answers a question the summary has already answered,
  # and answers it differently. Sensor::SummaryBuilder counts every inverter
  # that reported that day. A column of the same row is NULL for a day before
  # the user added that inverter.
  depends_on do |context: :unknown|
    next [] if Sensor::Config.configured?(:inverter_power)
    next %i[inverter_power inverter_power_total] if context == :sql

    %i[inverter_power_total]
  end

  calculate do |inverter_power: nil, inverter_power_total: nil, **|
    inverter_power || inverter_power_total
  end

  # Override calculated? to check for actual dependencies
  def calculated?
    dependencies.any?
  end

  # Always store inverter_power in summary, whether directly measured or calculated
  aggregations stored: %i[sum max], meta: %i[sum max min avg], top10: true

  home_pages :balance, :inverter

  chart do |timeframe, variant: nil|
    Sensor::Chart::InverterPower.new(timeframe:, variant:)
  end

  trend more_is_better: true
end
