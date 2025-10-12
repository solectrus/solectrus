class SegmentContainer::Component < ViewComponent::Base
  renders_many :segments,
               lambda { |sensor_name, **options, &block|
                 sensor = Sensor::Registry[sensor_name]
                 Segment::Component.new sensor, **options, parent: self, &block
               }
  renders_one :title

  def initialize(data:, timeframe:, tippy_placement:)
    super()
    @data = data
    @timeframe = timeframe
    @tippy_placement = tippy_placement
  end

  attr_reader :data, :timeframe, :tippy_placement
end
