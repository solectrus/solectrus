class ChartData::Base
  def initialize(timeframe:)
    @timeframe = timeframe
  end
  attr_reader :timeframe

  def call
    data
  end

  private

  def data
    # :nocov:
    raise NotImplementedError
    # :nocov:
  end

  def style
    { fill: 'origin', borderWidth: 1, borderRadius: 5, borderSkipped: 'start' }
  end
end
