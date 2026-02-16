class Sensor::Definitions::CustomPowerGrid < Sensor::Definitions::Base
  # Use the same MAX as CustomPower since they're related
  MAX = Sensor::Definitions::CustomPower::MAX
  public_constant :MAX

  def initialize(number)
    @number = number
    super()
  end

  def name
    :"custom_power_#{formatted_number}_grid"
  end

  value unit: :watt, category: :power_splitter

  color background: 'bg-sensor-grid',
        text: 'text-white dark:text-slate-400'

  aggregations stored: [:sum]

  requires_permission :power_splitter

  def display_name(_format = :short)
    "#{I18n.t('splitter.grid')} #{formatted_number}"
  end

  def corresponding_base_sensor
    Sensor::Registry[:"custom_power_#{formatted_number}"]
  end

  private

  def formatted_number
    format('%02d', @number)
  end
end
