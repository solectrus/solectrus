class InverterBreakdown::Tooltip::Component < ViewComponent::Base
  def initialize(sensor:, data:, timeframe:)
    super()
    @sensor = sensor
    @data = data
    @timeframe = timeframe
  end

  attr_reader :sensor, :data, :timeframe

  def call
    tag.div class: 'flex flex-col items-center justify-center min-w-32 p-2 gap-2' do
      safe_join(
        [
          sensor.display_name,
          sensor_value,
        ],
      )
    end
  end

  private

  def sensor_value
    if timeframe.now?
      render SensorValue::Component.new(data, sensor.name, precision: 3)
    else
      render SensorValue::Component.new(data, sensor.name, context: :total, precision: 3, class: 'text-xl')
    end
  end
end
