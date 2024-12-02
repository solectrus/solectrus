class SegmentContainer::Component < ViewComponent::Base
  renders_many :segments,
               lambda { |sensor, **options, &block|
                 if render_segment?(sensor)
                   Segment::Component.new sensor,
                                          **options,
                                          parent: self,
                                          &block
                 end
               }

  def initialize(calculator:, timeframe:, sensor:, tippy_placement:, title: nil)
    super
    @calculator = calculator
    @timeframe = timeframe
    @sensor = sensor
    @title = title
    @tippy_placement = tippy_placement
  end

  attr_reader :calculator, :timeframe, :sensor, :title, :tippy_placement

  private

  def render_segment?(sensor)
    # We never want a segment for a non-existing sensor
    return false unless SensorConfig.x.exists?(sensor)

    # On the "now" page the height is animated, so
    # we need to render even if the value is currently zero
    return true if timeframe.now?

    # Otherwise, we don't need a segment when value is zero
    calculator.public_send(sensor)&.nonzero?
  end
end
