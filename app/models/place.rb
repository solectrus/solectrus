# A place where a car stood (docs/cars.md). The user can give it a name of
# its own, for example "Home", and labels (see LABELS). Its address comes
# from Nominatim, but only when the user asks for the place, so each place
# asks Nominatim once at most. The record keeps the full answer
# (`geocoding`).
# == Schema Information
#
# Table name: places
#
#  id          :bigint           not null, primary key
#  geocoded_at :datetime
#  geocoding   :jsonb
#  labels      :string           default([]), not null, is an Array
#  latitude    :float            not null
#  longitude   :float            not null
#  name        :string
#  created_at  :datetime         not null
#  updated_at  :datetime         not null
#
# Indexes
#
#  index_places_on_home  ((1)) UNIQUE WHERE ('home'::text = ANY ((labels)::text[]))
#
class Place < ApplicationRecord
  # A position belongs to the nearest place within this distance in meters
  RADIUS = 100
  public_constant :RADIUS

  # A shorter stop gets no place of its own, for example a stop at a traffic
  # light. A car that reports less often needs a longer stop (see
  # Place::VisitDetection#limit).
  MIN_DURATION = 30.minutes
  public_constant :MIN_DURATION

  # A failed request to Nominatim waits this long before the next one, from
  # geocoded_at
  RETRY_AFTER = 10.minutes
  private_constant :RETRY_AFTER

  # The town of a location without a place stays this long in the cache (see
  # Place.name_at)
  TOWN_TTL = 1.week
  private_constant :TOWN_TTL

  # The labels that a place can have, each with its icon. A new label needs
  # no migration. `home` is the place of the wallbox (see
  # ChargingSession::Detection::CarAssignment), so only one place is home.
  LABELS = { 'home' => 'house' }.freeze
  public_constant :LABELS

  has_many :visits, class_name: 'PlaceVisit', dependent: :delete_all

  normalizes :name, with: -> { it.strip.presence }
  # In the order of LABELS, without the empty value of the form
  normalizes :labels, with: -> { LABELS.keys & it }

  validates :latitude, numericality: { in: -90..90 }
  validates :longitude, numericality: { in: -180..180 }

  # A new home takes the label from the old one
  before_save :release_home, if: -> { home? && labels_changed? }

  scope :labeled, ->(label) { where('? = ANY(labels)', label) }

  def self.home = labeled('home').first

  def self.human_label(label) = I18n.t("places.labels.#{label}")

  def home? = labels.include?('home')

  # Each place with the time of the cars there (`seconds`), from the visits of
  # the daily build, the place with the most time first. A place without a
  # visit has 0, for example a place that a click in the live view made.
  def self.with_seconds
    left_joins(:visits)
      .group(:id)
      .select('places.*', 'COALESCE(SUM(place_visits.seconds), 0) AS seconds')
      .order(Arel.sql('seconds DESC'), :id)
  end

  # The places in the box around a location, which holds each place within
  # RADIUS. The database selects them, so a request loads a few places and
  # not each place.
  def self.around(latitude, longitude)
    latitudes, longitudes = Geo.box(latitude, longitude, RADIUS)
    where(latitude: latitudes, longitude: longitudes)
  end

  # The nearest place within RADIUS, out of the given places
  def self.near(latitude, longitude, places = around(latitude, longitude))
    places
      .map { [it, it.distance_to(latitude, longitude)] }
      .select { |_, distance| distance <= RADIUS }
      .min_by(&:last)
      &.first
  end

  # The place of each stop (Place::VisitDetection::Stop), in the order of
  # the stops. A long stop (Stop#long?) gets a new place when no place is
  # near. A shorter stop without a place gets nil. A chunk of 7 days has
  # about 20 stops, because a stop joins the positions within RADIUS, so a
  # search through each place is fast enough (95 places: about 4 ms).
  #
  # Two builds can run at the same time, for example in two tabs. Neither
  # sees the new places of the other before its commit, so each would make
  # its own place at the same stop. The lock holds the second build until the
  # first one commits. PostgreSQL names an advisory lock by a number, so the
  # number comes from the name of the table.
  def self.of(stops)
    transaction do
      connection.execute("SELECT pg_advisory_xact_lock(hashtext('places'))")
      places = all.to_a

      stops.map do |stop|
        near(stop.latitude, stop.longitude, places) ||
          (create!(latitude: stop.latitude, longitude: stop.longitude).tap { places << it } if stop.long?)
      end
    end
  end

  # The name at a location without a request to Nominatim: the name of the
  # nearest place, or else the town from the cache. Nil before the first
  # answer of Nominatim (see Place.name_at).
  def self.known_name_at(latitude, longitude)
    place = near(latitude, longitude)
    place ? place.display_name : Rails.cache.read(town_key(latitude, longitude))
  end

  # The name at a location, which asks Nominatim when necessary. A place
  # keeps the answer (see #geocode!). A location without a place gets no new
  # place, because a car on the road must not leave places behind (see
  # Place.of). The cache keeps its town instead.
  def self.name_at(latitude, longitude)
    place = near(latitude, longitude)
    return place.geocode!.display_name if place

    Rails.cache.fetch(town_key(latitude, longitude), expires_in: TOWN_TTL, skip_nil: true) do
      new(latitude:, longitude:, geocoding: Place::Nominatim.reverse(latitude, longitude)).town
    end
  end

  # Two decimals are about one kilometer, so a car on the road asks Nominatim
  # far less often than the live view refreshes. A town is larger, so its name
  # stays correct except near its border. Nominatim answers in the locale.
  def self.town_key(latitude, longitude) = ['place-town', I18n.locale, latitude.round(2), longitude.round(2)]
  private_class_method :town_key

  # The name of the user, or the locality
  def display_name = name || locality

  # The town of the address, or nil before an answer of Nominatim
  def town
    address_parts.values_at('city', 'town', 'village', 'municipality').compact.first
  end

  # The part of the town, for example the suburb of a city or the village of
  # a small town, or nil. A village without a town is the town itself.
  def district
    district = address_parts.values_at('suburb', 'village', 'quarter', 'city_district').compact.first
    district unless district == town
  end

  # The district and the town: "Braunsfeld, Cologne". A district that names the
  # town stands alone, for example "Bonn-Zentrum".
  def locality
    return town unless district && town

    district.include?(town) ? district : "#{district}, #{town}"
  end

  # The street and the town: "Main Street 15, 12345 Town"
  def address
    parts = address_parts
    street = parts.values_at('road', 'house_number').compact.join(' ').presence
    locality = [parts['postcode'], town].compact.join(' ').presence

    [street, locality].compact.join(', ').presence
  end

  def geocoded? = geocoding.present?

  def distance_to(other_latitude, other_longitude)
    Geo.distance(latitude, longitude, other_latitude, other_longitude)
  end

  # Whether the position is within RADIUS of the place
  def covers?(other_latitude, other_longitude) = distance_to(other_latitude, other_longitude) <= RADIUS

  # Asks Nominatim for the address once. The answer stays in the record.
  def geocode!
    return self unless Place::Nominatim.enabled?
    return self if geocoded? || geocoded_at&.after?(RETRY_AFTER.ago)

    update!(geocoding: Place::Nominatim.reverse(latitude, longitude), geocoded_at: Time.current)
    self
  end

  private

  def address_parts = geocoding&.dig('address') || {}

  def release_home
    Place.labeled('home').where.not(id:).update_all(['labels = array_remove(labels, ?)', 'home']) # rubocop:disable Rails/SkipsModelValidations
  end
end
