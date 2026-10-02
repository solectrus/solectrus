# The driving cost of the car: each day drives its distance at the cost per km
# of the window around it (see Car::DailyRates). A column is the sum of its
# days, so it shows the same number as the driving cost tile of that period,
# and the columns add up to the tile of the timeframe.
#
# Unlike a rate, a cost of an hour means something. A day and shorter get
# hourly columns from the distance chart, each at the rate of its day.
#
# The tooltip of a column shows this calculation and says that each day has
# a window of its own.
class Sensor::Chart::CarDrivingCosts < Sensor::Chart::Base
  include Sensor::Chart::Concerns::CarDailyRates

  def chart_sensor_names
    %i[car_driving_costs]
  end

  # An hourly column is the cost of that hour, not a cost per hour.
  def unit
    @unit ||=
      Sensor::UnitFormatter.format(unit: :money, context: :total, scaling: :off)
  end

  private

  def build_data
    timeframe.short? ? build_hourly_data : build_bucket_data
  end

  def value(totals)
    totals.cost if totals.cost_rated?
  end

  # The calculation of the value (distance times rate) comes first.
  def notes(totals)
    [calculation(totals.cost_distance, totals.cost_per_100km / 100), daily_rate_note]
  end

  def build_hourly_data
    columns = hourly_columns
    return if columns.empty? || columns.values.none?

    labels = columns.keys.sort
    sensor = chart_sensors.first
    {
      labels:,
      datasets: [
        {
          **style_for_sensor(sensor),
          id: sensor.name.to_s,
          label:,
          data: labels.map { columns[it]&.first },
          tooltipNotes: labels.map { columns[it]&.last },
        },
      ],
    }
  end

  # { label => [cost, tooltip notes] } of each hour, or nil for an hour
  # without distance or without a cost rate of its day. Each car drives at
  # the rate of its own window, and the selection "all" adds the cars.
  def hourly_columns
    daily_rates.rates.each_with_object({}) do |rates, columns|
      hourly_costs(rates).each do |label, cost, line|
        columns[label] ||= nil
        next unless cost

        sum, lines = columns[label] || [0.0, []]
        columns[label] = [sum + cost, [*lines[0...-1], line, daily_rate_note]]
      end
    end
  end

  # [label, cost, calculation] of each hour of the distance chart of a car.
  # The cost is nil without a cost rate of the day.
  def hourly_costs(rates)
    kms = distances_of(rates.car)
    return [] unless kms

    kms.zip(distance[:labels]).map do |km, label|
      rate = rates.rate_on(Time.zone.at(label / 1000).to_date) if km
      next [label] unless rate&.cost_per_km

      line = calculation(km, rate.cost_per_km)
      line = "#{rates.car.display_name}: #{line}" if daily_rates.rates.size > 1
      [label, km * rate.cost_per_km, line]
    end
  end

  # The distance of each hour of a car, nil without its odometer
  def distances_of(car)
    name = Sensor::Cars.sensor_name(:car_mileage, car.id).to_s
    distance&.dig(:datasets)&.find { it[:id] == name }&.dig(:data)
  end

  # The distance chart of the selected cars, with a dataset for each car,
  # from one query
  def distance
    return @distance if defined?(@distance)

    @distance = Sensor::Chart::CarMileage.new(timeframe:, cars:).tap { it.interval = interval }.data
  end

  def calculation(distance, cost_per_km)
    rate_unit = Sensor::UnitFormatter.format(unit: :money_per_100km, context: :total)
    "#{Sensor::ValueFormatter.new(distance, unit: :kilometer)} × #{number(cost_per_km * 100, 2)} #{rate_unit}"
  end

  def number(value, precision)
    ActiveSupport::NumberHelper.number_to_rounded(value, precision:, delimiter: I18n.t('number.format.delimiter'))
  end
end
