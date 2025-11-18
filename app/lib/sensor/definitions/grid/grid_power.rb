class Sensor::Definitions::GridPower < Sensor::Definitions::Base
  value unit: :watt, category: :grid

  color hex: '#64748b',
        bg_classes: 'bg-slate-500 dark:bg-slate-700',
        text_classes: 'text-slate-100 dark:text-slate-400'

  icon 'fa-bolt'

  depends_on :grid_import_power, :grid_export_power

  calculate do |grid_import_power:, grid_export_power:, **|
    return unless grid_export_power && grid_import_power

    # Grid power is positive for export, negative for import
    grid_export_power - grid_import_power
  end

  aggregations stored: false, computed: [:sum], meta: [:sum]

  chart { |timeframe| Sensor::Chart::GridPower.new(timeframe:) }

  trend more_is_better: true
end
