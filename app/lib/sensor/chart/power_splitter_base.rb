class Sensor::Chart::PowerSplitterBase < Sensor::Chart::Base
  SPLITTER_MAIN_COLOR = 'bg-slate-600 dark:bg-slate-600'.freeze
  private_constant :SPLITTER_MAIN_COLOR

  private

  # Override chart_sensor_names to include power splitting sensors if available
  def chart_sensor_names
    if splitting_allowed?
      [base_sensor_name, grid_sensor_name, pv_sensor_name]
    else
      [base_sensor_name]
    end
  end

  # Override datasets to provide custom styling and stacking
  def datasets(chart_data_items)
    if splitting_allowed?
      build_splitted_datasets(chart_data_items)
    else
      super # Use base class implementation
    end
  end

  # Check if power splitting is allowed (requires power_splitter feature)
  def splitting_allowed?
    return false unless ApplicationPolicy.power_splitter?
    return false if timeframe.now? || timeframe.hours? || timeframe.day?

    # Only allow splitting if we have grid data configured
    Sensor::Config.exists?(grid_sensor_name)
  end

  # Build datasets for split power sources
  def build_splitted_datasets(chart_data_items)
    [
      build_main_dataset(chart_data_items.first),
      build_grid_dataset(chart_data_items.second),
      build_pv_dataset(chart_data_items.third),
    ]
  end

  # Base styling for all datasets
  def base_style
    {
      fill: true,
      tension: 0.4,
      borderSkipped: false,
      pointRadius: 0,
      pointHoverRadius: 5,
    }
  end

  # Subclasses must implement these methods to define sensor names
  def base_sensor_name
    # :nocov:
    raise NotImplementedError, 'Subclass must implement #base_sensor_name'
    # :nocov:
  end

  def grid_sensor_name
    # :nocov:
    raise NotImplementedError, 'Subclass must implement #grid_sensor_name'
    # :nocov:
  end

  def pv_sensor_name
    # :nocov:
    raise NotImplementedError, 'Subclass must implement #pv_sensor_name'
    # :nocov:
  end

  def build_main_dataset(chart_data_item)
    {
      # Gray consumption sidebar
      **base_style,
      id: chart_sensors.first.name,
      data: chart_data_item[:data],
      colorClass: SPLITTER_MAIN_COLOR,
      barPercentage: 0.7,
      categoryPercentage: 0.7,
      borderRadius: {
        topLeft: 5,
        bottomLeft: 0,
        topRight: 0,
        bottomRight: 0,
      },
      borderWidth: {
        top: 1,
        left: 1,
      },
    }
  end

  def build_grid_dataset(chart_data_item)
    {
      # Red grid portion
      **base_style,
      id: chart_sensors.second.name,
      label: I18n.t('splitter.grid'),
      data: chart_data_item[:data],
      stack: 'Power-Splitter',
      colorClass: Sensor::Registry[grid_sensor_name].color_chart,
      barPercentage: 1.3,
      categoryPercentage: 0.7,
      borderRadius: 0,
      borderWidth: {
        right: 1,
      },
    }
  end

  def build_pv_dataset(chart_data_item)
    {
      # Green PV portion
      **base_style,
      id: chart_sensors.third.name,
      label: I18n.t('splitter.pv'),
      data: chart_data_item[:data],
      stack: 'Power-Splitter',
      colorClass: Sensor::Registry[pv_sensor_name].color_chart,
      barPercentage: 1.3,
      categoryPercentage: 0.7,
      borderRadius: 0,
      borderWidth: {
        top: 1,
        right: 1,
      },
    }
  end
end
