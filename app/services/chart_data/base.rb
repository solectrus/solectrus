class ChartData::Base
  def initialize(timeframe:)
    @timeframe = timeframe
  end
  attr_reader :timeframe

  def to_h
    data
  end

  delegate :to_json, to: :to_h

  def blank?
    data[:datasets].blank? ||
      data[:datasets].all? { |dataset| dataset[:data].blank? }
  end

  private

  def data
    # :nocov:
    raise NotImplementedError
    # :nocov:
  end

  def style
    { fill: 'origin', borderWidth: 1, borderRadius: 3, borderSkipped: 'start' }
  end
end
