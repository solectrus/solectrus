# The places of the selected cars (see CarSelectable) on a map. A circle marks
# a place, and its size shows the share of the time of the cars at that
# place. The circles have one color for each selection of cars, so the map
# of one car looks like the map of all cars. The map loads the tooltip of a
# place when the pointer rests on it (see Cars::PlaceTooltipsController), so
# the page carries only the positions. The live view has no chart, so its cars show their place
# instead (see Car::LiveView::Component).
#
# The time comes from the visits of the daily build (see
# Place::VisitDetection), so the car page builds the days first (see
# Car::Report::STEPS). A day outside the period of use of a car has no visit
# of it.
class Sensor::Chart::CarLocation < Sensor::Chart::Base
  include Sensor::Chart::Concerns::SelectedCars

  def self.supports?(timeframe) = !timeframe.now? && !timeframe.hours?

  # Only a car with both coordinates has places
  def supported?
    super && cars.any?(&:located?)
  end

  def type = 'map'

  # The map loads the tooltip of a place for the timeframe
  def component = Car::Map::Component.new(cars: data[:cars], tooltip_timeframe: timeframe)

  # The guest sees the map without the places
  def teaser_component = Car::Map::Component.new(cars: [])

  def chart_sensor_names = [:car_location]

  def blank?
    data.blank? || data[:cars].all? { it[:places].empty? }
  end

  def blank_message = I18n.t('data.car_no_location')

  def blank_icon = 'location-dot'

  def unit = nil

  def options = {}

  private

  # { cars: [{ places: [[latitude, longitude, share, id], ...] }] }, with the
  # share of the time of the cars at a place, from 0 to 1, and the id of the
  # place for its tooltip. One query gives the time and the position of each
  # place.
  def build_data
    seconds =
      PlaceVisit.where(car: cars, date: timeframe.effective_dates).joins(:place)
        .group(:place_id, 'places.latitude', 'places.longitude').sum(:seconds)
    total = seconds.values.sum
    places =
      seconds.sort_by { -it.last }.map do |(id, latitude, longitude), time|
        [latitude.round(5), longitude.round(5), share(time, total), id]
      end

    { cars: [{ places: }] }
  end

  def share(time, total) = total.positive? ? time.fdiv(total).round(4) : 0
end
