class Sensor::Chart::SelfConsumptionQuote < Sensor::Chart::Base
  def chart_sensor_names
    %i[self_consumption_quote]
  end

  def meta_aggregation_for_timeframe(_sensor_def)
    :avg
  end
end
