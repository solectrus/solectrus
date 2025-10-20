class Insights::Extremum < Insights::Base
  def initialize(sensor:, timeframe:, aggregation:)
    raise ArgumentError unless sensor.is_a?(Sensor::Definitions::Base)
    raise ArgumentError unless timeframe.is_a?(Timeframe)
    raise ArgumentError if %i[max min].exclude?(aggregation)

    super(timeframe:)
    @sensor = sensor
    @aggregation = aggregation
  end

  attr_reader :sensor, :aggregation

  def call
    return if timeframe.day?
    return if sensor.summary_meta_aggregations.exclude?(aggregation)

    ranking_hash =
      Sensor::Query::Ranking.new(
        sensor.name,
        aggregation: :sum,
        period: :day,
        start: timeframe.effective_beginning_date,
        stop: timeframe.effective_ending_date,
        desc: aggregation == :max,
        limit: 1,
      ).call

    return if ranking_hash.empty?

    ranking_hash.first
  end
end
