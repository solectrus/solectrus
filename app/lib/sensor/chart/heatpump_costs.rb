class Sensor::Chart::HeatpumpCosts < Sensor::Chart::FinanceBase
  STACK_ID = 'HeatpumpCosts'.freeze
  private_constant :STACK_ID

  def finance_sensor_name
    :heatpump_costs
  end

  def chart_sensor_names
    %i[heatpump_costs_grid heatpump_costs_pv]
  end

  def source_sensor_names
    return chart_sensor_names unless timeframe.short?

    %i[heatpump_power heatpump_power_grid]
  end

  def y_scale_options
    super.merge(stacked: true)
  end

  def datasets(chart_data_items)
    grid_data = find_chart_data(chart_data_items, :heatpump_costs_grid)[:data]
    pv_data = find_chart_data(chart_data_items, :heatpump_costs_pv)[:data]

    [
      build_cost_dataset(
        :heatpump_costs_grid,
        I18n.t('sensors.grid_costs'),
        grid_data,
        Sensor::Registry[:heatpump_power_grid].color_background,
      ),
      build_cost_dataset(
        :heatpump_costs_pv,
        I18n.t('sensors.opportunity_costs'),
        pv_data,
        Sensor::Registry[:heatpump_power_pv].color_background,
      ),
    ]
  end

  protected

  def build_chart_data_items
    return super unless timeframe.short?

    prices = short_prices
    return empty_cost_items unless prices

    source_items = source_chart_data_items
    heatpump_item = find_chart_data(source_items, :heatpump_power)
    grid_item = find_chart_data(source_items, :heatpump_power_grid)
    labels = short_labels(heatpump_item, grid_item)

    build_short_cost_items(labels, heatpump_item, grid_item, *prices)
  end

  private

  def short_prices
    electricity_price = get_price(:electricity)
    feed_in_price = get_price(:feed_in)
    return unless electricity_price && feed_in_price

    [electricity_price, feed_in_price]
  end

  def short_labels(heatpump_item, grid_item)
    [heatpump_item, grid_item].max_by { |item| item[:labels].length }[:labels]
  end

  def build_short_cost_items(labels, heatpump_item, grid_item, electricity_price, feed_in_price)
    grid_costs = []
    pv_costs = []

    labels.each_index do |index|
      grid_cost, pv_cost = calculate_cost_values(
        heatpump_item[:data][index],
        grid_item[:data][index],
        electricity_price,
        feed_in_price,
      )
      grid_costs << grid_cost
      pv_costs << pv_cost
    end

    [
      { sensor_name: :heatpump_costs_grid, labels:, data: grid_costs },
      { sensor_name: :heatpump_costs_pv, labels:, data: pv_costs },
    ]
  end

  def calculate_cost_values(total_power, grid_power, electricity_price, feed_in_price)
    total_power ||= 0
    grid_power = [grid_power || 0, total_power].min
    pv_power = [total_power - grid_power, 0].max

    [
      calculate_euro_rate(grid_power, electricity_price),
      calculate_euro_rate(pv_power, feed_in_price),
    ]
  end

  def empty_cost_items
    [
      { sensor_name: :heatpump_costs_grid, labels: [], data: [] },
      { sensor_name: :heatpump_costs_pv, labels: [], data: [] },
    ]
  end

  def build_cost_dataset(sensor_id, label, data, color_class)
    {
      id: sensor_id.to_s,
      label:,
      data:,
      stack: STACK_ID,
      noGradient: true,
      fill: true,
      borderWidth: 1,
      pointRadius: 0,
      pointHoverRadius: 5,
      colorClass: color_class,
    }
  end
end
