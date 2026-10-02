# == Schema Information
#
# Table name: charging_sessions
#
#  id         :bigint           not null, primary key
#  address    :string
#  cost       :decimal(10, 2)
#  cost_grid  :decimal(10, 2)
#  ended_at   :datetime
#  guest      :boolean          default(FALSE), not null
#  kind       :string           not null
#  kwh        :decimal(10, 3)   not null
#  kwh_grid   :decimal(10, 3)
#  note       :text
#  power_type :string
#  provider   :string
#  started_at :datetime         not null
#  created_at :datetime         not null
#  updated_at :datetime         not null
#  car_id     :integer
#  evse_id    :string
#
# Indexes
#
#  index_charging_sessions_on_car_id_and_started_at  (car_id,started_at)
#  index_charging_sessions_on_kind_and_started_at    (kind,started_at)
#  index_charging_sessions_on_wallbox_start          (started_at) UNIQUE WHERE ((kind)::text = 'wallbox'::text)
#
# Foreign Keys
#
#  charging_sessions_car_id_fkey  (car_id => cars.id)
#
# A charge of a car. The kind says where the energy flowed, and it also gives
# the source: the detection writes each wallbox session from the curve of the
# wallbox (see ChargingSession::Detection), and the user enters each offsite
# session.
#
# A wallbox session is in one of three states: it belongs to a car, it is a
# guest charge, or it is not assigned yet. Only a session of a car counts for
# a car. A guest charge is a decision of the user, and "not assigned" is an
# open task.
class ChargingSession < ApplicationRecord
  enum :kind, wallbox: 'wallbox', offsite: 'offsite'

  enum :power_type, ac: 'ac', dc: 'dc'

  belongs_to :car, optional: true

  validates :kind, presence: true
  validates :started_at, presence: true
  validates :kwh, presence: true, numericality: { greater_than: 0 }
  validates :cost,
            presence: true,
            numericality: { greater_than_or_equal_to: 0 },
            if: :offsite?
  validates :car, presence: true, if: :offsite?
  validates :ended_at, presence: true, if: :wallbox?
  validate :guest_without_car
  validate :car_active, if: -> { car && (will_save_change_to_car_id? || will_save_change_to_started_at?) }

  scope :in_range, ->(from, to) { where(started_at: from..to) }
  scope :not_assigned, -> { wallbox.where(car_id: nil, guest: false) }

  # The sessions of the given cars
  scope :of_cars, ->(cars) { where(car: cars) }

  scope :list_for,
        lambda { |kind, timeframe: nil, filter: nil|
          scope = where(kind:).order(started_at: :desc)
          scope = scope.in_range(timeframe.beginning, timeframe.ending) if timeframe && !timeframe.all?
          case filter
          when :not_assigned then scope.not_assigned
          when :guest then scope.where(guest: true)
          when Integer then scope.where(car_id: filter)
          else scope
          end
        }

  # A session belongs to the local date of its start, so a charge at 23:30
  # stays on the day of the distance beside it.
  def date = started_at.in_time_zone.to_date

  # :car, :guest or :not_assigned
  def state
    return :car if car_id
    return :guest if guest?

    :not_assigned
  end

  # The PV share of the energy. An offsite session and a session without the
  # power splitter have none.
  def kwh_pv
    return 0 if offsite?

    kwh - kwh_grid if kwh_grid
  end

  # The PV share in whole percent, nil without the power splitter
  def pv_percent
    share = kwh_pv
    (share * 100 / kwh).round if share && kwh.positive?
  end

  # Totals of the energy (kWh) and the cost of the sessions, with their count,
  # the count of sessions without a cost and the count of wallbox sessions
  # without a grid share (no power splitter).
  def self.totals
    kwh, kwh_grid, cost, count, without_cost, without_split =
      pick(
        Arel.sql('COALESCE(SUM(kwh), 0)'),
        Arel.sql("COALESCE(SUM(CASE WHEN kind = 'offsite' THEN kwh ELSE COALESCE(kwh_grid, kwh) END), 0)"),
        Arel.sql('COALESCE(SUM(cost), 0)'),
        Arel.sql('COUNT(*)'),
        Arel.sql('COUNT(*) FILTER (WHERE cost IS NULL)'),
        Arel.sql("COUNT(*) FILTER (WHERE kind = 'wallbox' AND kwh_grid IS NULL)"),
      )

    { kwh: kwh.to_f, kwh_grid: kwh_grid.to_f, cost: cost.to_f, count:, without_cost:, without_split: }
  end

  private

  def guest_without_car
    return unless guest?

    errors.add(:guest, :wallbox_only) unless wallbox?
    errors.add(:guest, :without_car) if car_id
  end

  # The period of a car limits the cars that can get a session
  def car_active
    return if started_at.nil? || car.active_on?(date)

    errors.add(:car_id, :inactive)
  end
end
