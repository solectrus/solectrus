# Wraps the stats of the live view. Sensor::Query::Latest drops every reading
# older than its MAX_AGE, so in an outage of the collector or of its
# connection the stats have nothing to draw. The component then shows the
# time of the last power reading in place of its block. It marks itself with
# `data-hides-chart`, so the chart, which stays empty as well, steps aside
# (see StatsWithChart::Component).
class NoCurrentReading::Component < ViewComponent::Base
  def initialize(data:)
    super()
    @data = data
  end

  def stale? = @data.timeframe.now? && !Sensor::Query::Latest.current?(time)

  # Sensor::Query::Latest looks back a day, so without a time the last power
  # reading is older than that, or there never was one
  def last_reading
    return t('.none_in_day') unless time

    "#{t('data.time')} #{helpers.time_ago_in_words(time)}"
  end

  private

  def time = @data.power_time
end
