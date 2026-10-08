# A visit of a car at a place, from its arrival to its departure. The daily
# build writes it (see Place::VisitDetection) and cuts it at midnight, so a
# night at home has a row on each of the two days. The map and the list of the
# places add up the time of the rows, and the list of the visits joins the
# rows of a visit again (see .joined).
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

  # The visits of the scope, each in one row, the latest first. A row joins
  # the next row of the car when that row starts at its end at the same
  # place, which is the cut at midnight. The first window marks each row that
  # starts a visit, and the second numbers the visits of each car by the
  # sum of these marks.
  def self.joined
    marked = select(
      :id,
      :car_id,
      :place_id,
      :started_at,
      :ended_at,
      :seconds,
      Arel.sql(<<~SQL.squish),
        CASE WHEN started_at = LAG(ended_at) OVER (PARTITION BY car_id ORDER BY started_at)
              AND place_id = LAG(place_id) OVER (PARTITION BY car_id ORDER BY started_at)
        THEN 0 ELSE 1 END AS first_row
      SQL
    )
    numbered = unscoped.from(marked, table_name).select(
      "#{table_name}.*",
      'SUM(first_row) OVER (PARTITION BY car_id ORDER BY started_at) AS visit',
    )
    visits = unscoped.from(numbered, table_name)
      .select(
        'MIN(id) AS id',
        :car_id,
        :place_id,
        'MIN(started_at) AS started_at',
        'MAX(ended_at) AS ended_at',
        'SUM(seconds)::integer AS seconds',
      )
      .group(:car_id, :place_id, :visit)

    unscoped.from(visits, table_name).order(started_at: :desc, car_id: :asc)
  end

  # Whether the car is still at the place. The table does not know it, so
  # .mark_ongoing sets it from the latest position.
  attribute :ongoing, :boolean, default: false

  # Marks the latest visit of each car among the joined `visits` as ongoing
  # while the car is still at its place. The latest position comes from
  # InfluxDB, like in the live view (see Car::Live), so it asks only for a
  # car whose latest visit is among them.
  def self.mark_ongoing(visits)
    latest = unscoped.group(:car_id).maximum(:ended_at)
    candidates = visits.select { latest[it.car_id] == it.ended_at }
    return if candidates.empty?

    states = Car::Live.new(candidates.map(&:car).uniq).states.index_by { it.car.id }
    candidates.each do |visit|
      location = states[visit.car_id]&.location
      visit.ongoing = location.present? && visit.place.covers?(*location)
    end
  end

  # The time of the visit. An ongoing visit lasts up to now, beyond the run
  # of the build that wrote it.
  def current_seconds = ongoing? ? (Time.current - started_at).to_i : seconds

  # The joined visits that overlap the days of the timeframe, with their full
  # time, also before and after the timeframe
  def self.overlapping(timeframe)
    where(
      'started_at < ? AND ended_at > ?',
      timeframe.effective_ending_date.next_day.beginning_of_day,
      timeframe.effective_beginning_date.beginning_of_day,
    )
  end

  # The number of the joined visits of the scope that overlap the timeframe,
  # and the number of their places, in one query. The cut at midnight gives
  # each such visit a row on a day of the timeframe, so the rows of the other
  # days can go before the join.
  def self.counts(timeframe)
    visits, places =
      where(date: timeframe.effective_dates)
      .joined
      .overlapping(timeframe)
      .unscope(:order)
      .pick(Arel.sql('COUNT(*)'), Arel.sql("COUNT(DISTINCT #{table_name}.place_id)"))

    { visits:, places: }
  end
end
