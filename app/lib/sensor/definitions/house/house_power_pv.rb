class Sensor::Definitions::HousePowerPv < Sensor::Definitions::Base
  value unit: :watt, category: :power_splitter

  color hex: '#16a34a',
        bg_classes: 'bg-green-600 dark:bg-green-800',
        text_classes: 'text-green-100 dark:text-green-400'

  depends_on :house_power, :house_power_grid

  calculate do |house_power:, house_power_grid:, **|
    return unless house_power && house_power_grid

    house_power - house_power_grid
  end

  aggregations stored: false, computed: [:sum], meta: [:sum]

  requires_permission :power_splitter
end
