class Sensor::Definitions::HousePowerPv < Sensor::Definitions::Base
  value unit: :watt, range: (0..), category: :power_splitter

  color background: 'bg-emerald-600 dark:bg-emerald-800',
        text: 'text-emerald-100 dark:text-emerald-400'

  depends_on :house_power, :house_power_grid

  calculate do |house_power:, house_power_grid:, **|
    return unless house_power && house_power_grid

    house_power - house_power_grid
  end

  aggregations stored: false, computed: [:sum], meta: [:sum]

  requires_permission :power_splitter
end
