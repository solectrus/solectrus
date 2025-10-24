class Sensor::Definitions::CustomInverterPower < Sensor::Definitions::Base
  MAX = 5 # Maximum number of custom inverter sensors
  public_constant :MAX

  def initialize(number)
    @number = number
    super()
  end

  def name
    :"inverter_power_#{@number}"
  end

  value unit: :watt, range: (0..), category: :inverter, nameable: true

  icon 'fa-sun'

  color do |index|
    # Based on '#16a34a' (green-600)
    color_sets = [
      {
        hex: '#166534',
        bg: 'bg-[#166534]',
        text: 'text-slate-100 dark:text-slate-300',
      },
      {
        hex: '#16753A',
        bg: 'bg-[#16753A]',
        text: 'text-slate-100 dark:text-slate-300',
      },
      {
        hex: '#16843F',
        bg: 'bg-[#16843F]',
        text: 'text-slate-100 dark:text-slate-300',
      },
      {
        hex: '#169445',
        bg: 'bg-[#169445]',
        text: 'text-slate-100 dark:text-slate-300',
      },
      {
        hex: '#16A34A',
        bg: 'bg-[#16A34A]',
        text: 'text-slate-100 dark:text-slate-300',
      },
    ]
    # Use provided index or @number (inverters are always sorted by number, not dynamically)
    effective_index = index || @number
    color_sets[(effective_index - 1) % color_sets.length]
  end

  aggregations stored: %i[sum max], top10: true

  chart do |timeframe, variant: nil|
    Sensor::Chart::CustomInverterPower.new(
      timeframe:,
      sensor_name: name,
      variant:,
    )
  end

  trend more_is_better: true

  def display_name(format = :long)
    base_name = super

    if format == :long
      prefix = I18n.t('sensors.inverter_power')
      base_name.start_with?(prefix) ? base_name : "#{prefix} #{base_name}"
    else
      base_name
    end
  end
end
