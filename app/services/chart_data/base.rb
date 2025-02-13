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
    data.nil? || data[:datasets].blank? ||
      data[:datasets].all? { |dataset| dataset[:data]&.compact.blank? }
  end

  def type
    timeframe.short? ? 'line' : 'bar'
  end

  def options
    {}
  end

  def suggested_max
  end

  def suggested_min
    0
  end

  private

  def data
    # :nocov:
    raise NotImplementedError
    # :nocov:
  end

  def style
    {
      fill: 'origin',
      borderWidth: 1,
      borderRadius: 3,
      borderSkipped: 'start',
      minBarLength: 3,
    }
  end
end
