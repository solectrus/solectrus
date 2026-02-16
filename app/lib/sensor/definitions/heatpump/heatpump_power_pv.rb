class Sensor::Definitions::HeatpumpPowerPv < Sensor::Definitions::Base
  value unit: :watt, category: :power_splitter

  color background: 'bg-sensor-pv',
        text: 'text-white dark:text-slate-400'

  depends_on :heatpump_power, :heatpump_power_grid

  calculate do |heatpump_power:, heatpump_power_grid:, **|
    return unless heatpump_power && heatpump_power_grid

    [heatpump_power - heatpump_power_grid, 0].max
  end

  aggregations stored: false, computed: [:sum], meta: [:sum]

  requires_permission :power_splitter

  def display_name(_format = :short)
    I18n.t('splitter.pv')
  end
end
