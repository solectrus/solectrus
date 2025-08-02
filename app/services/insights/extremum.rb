class Insights::Extremum < Insights::Base
  def initialize(sensor:, timeframe:, aggregation:)
    super(timeframe:)
    @sensor = sensor
    @aggregation = aggregation
  end

  attr_reader :sensor, :aggregation

  def call
    return if timeframe.day?
    return unless sensor.in?(SensorConfig::TOP10_SENSORS)

    top =
      PowerRanking.new(
        sensor:,
        desc: aggregation == :max,
        calc: 'sum',
        from: timeframe.effective_beginning_date,
        to: timeframe.effective_ending_date,
        limit: 1,
      )

    top.days.first
  end
end
