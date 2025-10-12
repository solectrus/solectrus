class SegmentContainer::Component < ViewComponent::Base
  renders_many :segments,
               lambda { |sensor, **options, &block|
                 if SensorConfig.x.exists?(sensor)
                   Segment::Component.new sensor,
                                          **options,
                                          parent: self,
                                          &block
                 end
               }
  renders_one :title

  def initialize(calculator:, timeframe:, tippy_placement:)
    super()
    @calculator = calculator
    @timeframe = timeframe
    @tippy_placement = tippy_placement
  end

  attr_reader :calculator, :timeframe, :tippy_placement
end
