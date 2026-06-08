class Sensor::Chart::PowerSplitterBase < Sensor::Chart::Base
  private

  # Override chart_sensor_names to include power splitting sensors if available
  def chart_sensor_names
    if splitting_allowed?
      [base_sensor_name, grid_sensor_name, pv_sensor_name]
    else
      [base_sensor_name]
    end
  end

  # Override datasets to provide custom styling and stacking for split power sources
  def datasets(chart_data_items)
    if splitting_allowed? && split_data_present?(chart_data_items)
      build_splitted_datasets(chart_data_items)
    else
      # No actual split data: render the base sensor as a single, full-width
      # dataset. Emitting the empty grid/pv datasets would reserve a second
      # bar slot next to the main bar and squeeze it into a thin sliver.
      super(chart_data_items.first(1))
    end
  end

  # Check if power splitting is allowed (requires power_splitter feature)
  def splitting_allowed?
    return false unless ApplicationPolicy.power_splitter?
    return false if timeframe.now? || timeframe.hours? || timeframe.day?

    # Only allow splitting if we have grid data configured
    Sensor::Config.exists?(grid_sensor_name)
  end

  # The grid sensor can be auto-configured and permitted (sponsor) while the
  # power_splitter measurement stays empty -- e.g. when the splitter service
  # isn't running. In that case grid/pv carry only nils, so fall back to the
  # plain single-dataset chart.
  def split_data_present?(chart_data_items)
    [chart_data_items.second, chart_data_items.third].compact.any? do |item|
      item[:data]&.any? { |value| !value.nil? }
    end
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
      cubicInterpolationMode: 'monotone',
      borderSkipped: false,
      pointRadius: 0,
      pointHoverRadius: 5,
      noGradient: true,
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
      **base_style,
      id: chart_sensors.first.name,
      data: chart_data_item[:data],
      colorClass: color_class(chart_sensors.first),
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
      **base_style,
      id: chart_sensors.second.name,
      label: I18n.t('splitter.grid'),
      data: chart_data_item[:data],
      stack: 'Power-Splitter',
      colorClass: Sensor::Registry[grid_sensor_name].color_background,
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
      **base_style,
      id: chart_sensors.third.name,
      label: I18n.t('splitter.pv'),
      data: chart_data_item[:data],
      stack: 'Power-Splitter',
      colorClass: Sensor::Registry[pv_sensor_name].color_background,
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
