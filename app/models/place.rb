# A place where a car stood (docs/cars.md). The user can give it a name of
# its own, for example "Home", and labels (see LABELS).
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

  def home? = labels.include?('home')

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

  def distance_to(other_latitude, other_longitude)
    Geo.distance(latitude, longitude, other_latitude, other_longitude)
  end

  # Whether the position is within RADIUS of the place
  def covers?(other_latitude, other_longitude) = distance_to(other_latitude, other_longitude) <= RADIUS

  private

  def release_home
    Place.labeled('home').where.not(id:).update_all(['labels = array_remove(labels, ?)', 'home']) # rubocop:disable Rails/SkipsModelValidations
  end
end
