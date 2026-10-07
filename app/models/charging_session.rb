# == Schema Information
#
# Table name: charging_sessions
#
#  id                :bigint           not null, primary key
#  address           :string
#  assigned_manually :boolean          default(FALSE), not null
#  cost              :decimal(10, 2)
#  cost_grid         :decimal(10, 2)
#  ended_at          :datetime
#  guest             :boolean          default(FALSE), not null
#  kind              :string           not null
#  kwh               :decimal(10, 3)   not null
#  kwh_grid          :decimal(10, 3)
#  note              :text
#  origin            :string           not null
#  power_type        :string
#  provider          :string
#  started_at        :datetime         not null
#  created_at        :datetime         not null
#  updated_at        :datetime         not null
#  car_id            :integer
#  evse_id           :string
#
# Indexes
#
#  index_charging_sessions_on_car_id_and_started_at  (car_id,started_at)
#  index_charging_sessions_on_kind_and_started_at    (kind,started_at)
#  index_charging_sessions_on_wallbox_start          (started_at) UNIQUE WHERE (((kind)::text = 'wallbox'::text) AND ((origin)::text = 'detection'::text))
#
# Foreign Keys
#
#  charging_sessions_car_id_fkey  (car_id => cars.id)
#
# A charge of a car. The kind says where the energy flowed, and the origin
# says who made the row: the detection (see ChargingSession::Detection) or
# the user.
#
# A wallbox session is in one of three states: it belongs to a car, it is a
# guest charge, or it is not assigned yet. Only a session of a car counts for
# a car. A guest charge is a decision of the user, and "not assigned" is an
# open task.
#
# `assigned_manually` marks a state that the user chose. A new build of the
# detection never changes it (see ChargingSession::Detection::Persistence).
# The user enters each offsite session, so the user also chose its car.
class ChargingSession < ApplicationRecord
  include ChargingSession::Holder
  include ChargingSession::Repricing

  enum :kind, wallbox: 'wallbox', offsite: 'offsite'
  enum :origin, { detection: 'detection', user: 'user' }, prefix: true
  enum :power_type, { ac: 'ac', dc: 'dc' }, prefix: true

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
  validate :car_active, if: -> { car && changed.intersect?(%w[car_id started_at ended_at]) }

  # The detection writes with an upsert, which skips the callbacks. So a save
  # through the model that chooses the state is a choice of the user: an
  # offsite session, a guest mark, or a change of the car or the guest mark.
  before_save -> { self.assigned_manually = true },
              if: -> { offsite? || guest? || (persisted? && (will_save_change_to_car_id? || will_save_change_to_guest?)) }

  # The detection writes each wallbox session again, so only an offsite
  # session can go. The detection removes a wallbox session with a delete,
  # which skips this.
  before_destroy { throw(:abort) if wallbox? }

  # The sessions that start on the given local dates, whose end can be open
  scope :on_dates, ->(dates) { where(started_at: dates.begin.beginning_of_day..dates.end&.end_of_day) }
  scope :unassigned, -> { wallbox.where(car_id: nil, guest: false) }

  # { [car id, guest, local date, kind] => Sums } of the sessions of the
  # scope. The local date is the same day as #date. The rows grow with the
  # days, not with the sessions.
  def self.daily_sums
    local_date = Arel.sql("(started_at AT TIME ZONE 'UTC' AT TIME ZONE #{connection.quote(Time.zone.tzinfo.name)})::date")
    columns = [:car_id, :guest, local_date, :kind]

    group(*columns).pluck(*columns, *ChargingSession::Sums.sql).to_h do |row|
      [row.first(columns.size), ChargingSession::Sums.from_row(row.drop(columns.size))]
    end
  end

  # A session belongs to the local date of its start, so a charge at 23:30
  # stays on the day of the distance beside it.
  def date = started_at.in_time_zone.to_date

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

  private

  def guest_without_car
    return unless guest?

    errors.add(:guest, :wallbox_only) unless wallbox?
    errors.add(:guest, :without_car) if car_id
  end

  # The period of a car limits the cars that can get a session: the session
  # starts and ends in it
  def car_active
    return if started_at.nil? || [started_at, ended_at].compact.all? { car.period_times.cover?(it) }

    errors.add(:car_id, :inactive)
  end
end
