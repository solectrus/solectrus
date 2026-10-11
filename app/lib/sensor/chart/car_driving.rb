# The driving of the selected cars (see CarSelectable) in a column for each
# day, month or year: the driving cost, the cost per 100 km or the energy per
# 100 km. Each day drives at the rates of the window around it (see
# Car::Driving), so a column is the sum of its days. A column without a day
# with a rate has a gap, and a column that the timeframe cuts is hatched.
#
# The tooltip of a column says that each day has a window of its own. The
# driving cost shows its calculation first: the distance times the rate.
#
# Several cars stack the driving cost by car, each part in the color of the
# chart with a tint of its car. A rate stays one column, because the rates of
# the cars do not add up.
class Sensor::Chart::CarDriving < Sensor::Chart::Base
  include Sensor::Chart::Concerns::CarColumns

  # The stack of the parts of the cars, which the tooltip adds up
  STACK = 'CarDrivingCosts'.freeze
  private_constant :STACK

  # The metric is the sensor of the chart, like car_cost_rate
  def initialize(metric:, **)
    super(**)
    @metric = metric
  end

  attr_reader :metric

  # The driving needs the distance, so only a car with an odometer has it
  def supported?
    super && report.driving?
  end

  def chart_sensor_names
    [metric]
  end

  # Each column is a number of its own, and a line would suggest a flow
  def type
    'bar'
  end

  # A rate has the fixed precision of its unit: 18.4 kWh/100 km, 2.53 EUR/100 km
  def decimals
    chart_sensors.first.exact_precision unless metric == :car_driving_costs
  end

  private

  def build_data
    return if columns.empty?

    totals = columns.map { report.driving(it) }
    values = totals.map { value(it) }
    tooltip_notes = totals.zip(values).map { |sum, value| notes(sum) if value }
    datasets =
      if metric == :car_driving_costs && cars.many?
        car_datasets(tooltip_notes)
      else
        [dataset(chart_sensor_names.first, label, values, tooltip_notes)]
      end

    { labels:, datasets: }
  end

  # A part for each car with a driving cost in the timeframe, tinted with the
  # color of the car, from the bottom up in the order of the cars. Each part
  # shows the notes of its whole column, because the tooltip shows the notes of
  # one part.
  def car_datasets(tooltip_notes)
    cars.filter_map do |car|
      data = columns.map { value(report.driving(it, cars: [car])) }
      next if data.none?

      dataset("car_#{car.id}", car.display_name, data, tooltip_notes)
        .merge(stack: STACK, summed: true, tintColor: car.display_color)
    end
  end

  def dataset(id, label, data, tooltip_notes)
    {
      **style_for_sensor(chart_sensors.first),
      id: id.to_s,
      label:,
      data:,
      tooltipNotes: tooltip_notes,
      hatchFill: columns.map { partial?(it) },
    }
  end

  # The value of a column, or nil without a rate
  def value(totals)
    case metric
    when :car_driving_costs then totals.cost if totals.cost_rated?
    when :car_cost_rate then totals.cost_per_100km
    when :car_consumption_rate then totals.consumption_per_100km
    end
  end

  # The lines below the value in the tooltip
  def notes(totals)
    daily_rate = I18n.t('car_breakdown.daily_rate', days: Car::Driving::MARGIN_DAYS)
    return [daily_rate] unless metric == :car_driving_costs

    [calculation(totals.cost_distance, totals.cost_per_100km), daily_rate]
  end

  def calculation(distance, cost_per_100km)
    "#{Sensor::ValueFormatter.new(distance, unit: :kilometer)} × #{Sensor::ValueFormatter.new(cost_per_100km, unit: :money_per_100km)}"
  end
end
