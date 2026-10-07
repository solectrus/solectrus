# A visit of a car at a place, from its arrival to its departure. The daily
# build writes it (see Place::VisitDetection) and cuts it at midnight, so a
# night at home has a row on each of the two days.
# == Schema Information
#
# Table name: place_visits
#
#  id         :bigint           not null, primary key
#  date       :date             not null
#  ended_at   :datetime         not null
#  seconds    :integer
#  started_at :datetime         not null
#  car_id     :integer          not null
#  place_id   :bigint           not null
#
# Indexes
#
#  index_place_visits_on_car_id_and_started_at    (car_id,started_at) UNIQUE
#  index_place_visits_on_date                     (date)
#  index_place_visits_on_place_id_and_started_at  (place_id,started_at)
#
# Foreign Keys
#
#  fk_rails_...  (car_id => cars.id)
#  fk_rails_...  (place_id => places.id) ON DELETE => cascade
#
class PlaceVisit < ApplicationRecord
  belongs_to :car
  belongs_to :place
end
