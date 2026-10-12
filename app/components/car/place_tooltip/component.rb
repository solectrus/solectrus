# The tooltip of a place on the map of a period (see Car::Map::Component). The
# map loads it when the pointer rests on the place (see
# Cars::PlaceTooltipsController). It names the place with the icons of its
# labels, then its visits and the time of the cars there, the links to the
# form of the place and to Google Maps, and the cars of the place. Home
# has neither the visits nor the time.
class Car::PlaceTooltip::Component < ViewComponent::Base
  # `visits` are the rows of the visits of the `cars` at the place in the
  # timeframe (see PlaceVisit), and `visits_path` is their list
  def initialize(place:, cars:, visits:, visits_path:)
    super()
    @place = place
    @cars = cars
    @visits = visits
    @visits_path = visits_path
  end

  attr_reader :place, :visits_path

  def name = place.display_name || t('.unknown_place')

  def label_icons = place.labels.map { [it, Place::LABELS[it]] }

  # The visits and the time, in one line
  def facts
    @facts ||= place.home? ? [] : [visits_link, DurationText.call(stats.sum { it[:seconds] })].compact
  end

  # The cars of the place, the car with the most time first
  def cars
    cars_by_id = @cars.index_by(&:id)
    stats.sort_by { -it[:seconds] }.map { cars_by_id[it[:car_id]] }
  end

  # Google Maps with a pin at the place. Street View at the place itself often
  # has no image, because a car stands away from the road, but Google Maps
  # shows the nearest one. Google gets the position only with the click.
  def google_maps_url
    "https://www.google.com/maps/search/?#{{ api: 1, query: "#{place.latitude.round(5)},#{place.longitude.round(5)}" }.to_query}"
  end

  private

  # The visits of each car at the place as { car_id:, count:, started_at:,
  # seconds: }, in one query. The rows join to the visits of the list of the
  # visits, so a visit across midnight counts once.
  def stats
    @stats ||=
      @visits.joined.unscope(:order).group(:car_id)
        .pluck(:car_id, Arel.sql('COUNT(*)'), Arel.sql('MIN(started_at)'), Arel.sql('SUM(seconds)'))
        .map { |car_id, count, started_at, seconds| { car_id:, count:, started_at:, seconds: } }
  end

  # The number of the visits, or the day of a single visit
  def visits_link
    count = stats.sum { it[:count] }
    return unless count.positive?

    label = count > 1 ? t('.visits', count:) : l(stats.sole[:started_at].in_time_zone.to_date)
    link_to label, visits_path, class: LINK_CLASS, data: { turbo_frame: '_top' }
  end

  LINK_CLASS = 'text-indigo-600 dark:text-indigo-400 hover:underline underline-offset-4 focus-ring rounded'.freeze
  private_constant :LINK_CLASS
end
