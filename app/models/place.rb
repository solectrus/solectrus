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

  # The labels that a place can have, each with its icon. A new label needs
  # no migration. `home` is the place of the wallbox (see
  # ChargingSession::Detection::CarAssignment), so only one place is home.
  LABELS = { 'home' => 'house' }.freeze
  public_constant :LABELS

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
