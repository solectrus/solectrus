class Insights::Base
  def initialize(timeframe:, **options)
    @timeframe = timeframe
    @options = options
  end

  attr_reader :timeframe, :options

  def call
    raise NotImplementedError
  end
end
