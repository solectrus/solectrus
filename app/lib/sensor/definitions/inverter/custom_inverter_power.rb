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
    # Green color variations (based on green-600)
    color_sets = [
      { background: 'bg-emerald-800', text: 'text-slate-100 dark:text-slate-300' },
      { background: 'bg-emerald-700', text: 'text-slate-100 dark:text-slate-300' },
      { background: 'bg-emerald-600', text: 'text-slate-100 dark:text-slate-300' },
      { background: 'bg-emerald-500', text: 'text-slate-100 dark:text-slate-300' },
      { background: 'bg-emerald-400', text: 'text-slate-100 dark:text-slate-300' },
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
end
