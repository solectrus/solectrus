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

  # The sessions of one kind and one holder in the order of time, the window
  # of a charge over midnight (see .with_continued)
  HOLDER_WINDOW = '(PARTITION BY kind, car_id, guest ORDER BY started_at)'.freeze
  private_constant :HOLDER_WINDOW

  # Whether a session continues the session before it (see .with_continued).
  # The gap is a bind in seconds.
  CONTINUED_SQL = <<~SQL.squish.freeze
    COALESCE(
      kind = 'wallbox'
      AND started_at - LAG(ended_at) OVER #{HOLDER_WINDOW} <= :gap * INTERVAL '1 second'
      AND local_date > LAG(local_date) OVER #{HOLDER_WINDOW},
      FALSE
    ) AS continued
  SQL
  private_constant :CONTINUED_SQL

  # The number of the charge of each session of a holder (see .joined)
  CHARGE_NUMBER_SQL = "COUNT(*) FILTER (WHERE NOT continued) OVER #{HOLDER_WINDOW} AS charge_number".freeze
  private_constant :CHARGE_NUMBER_SQL

  # The columns of a charge (see .joined). A sum is missing when a part
  # misses it.
  CHARGE_COLUMNS = [
    '(ARRAY_AGG(id ORDER BY started_at))[1] AS id',
    'ARRAY_AGG(id ORDER BY started_at) AS part_ids',
    'kind',
    'car_id',
    'guest',
    'BOOL_OR(assigned_manually) AS assigned_manually',
    'MIN(started_at) AS started_at',
    'MAX(ended_at) AS ended_at',
    *%w[kwh kwh_grid cost cost_grid].map { "CASE WHEN COUNT(#{it}) = COUNT(*) THEN SUM(#{it}) END AS #{it}" },
    *%w[evse_id power_type provider address].map { "MIN(#{it}) AS #{it}" },
    "STRING_AGG(note, E'\\n' ORDER BY started_at) AS note",
    'MIN(created_at) AS created_at',
    'MAX(updated_at) AS updated_at',
  ].map { Arel.sql(it) }.freeze
  private_constant :CHARGE_COLUMNS

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

  # The list of the charges of a kind (see .joined), newest first. The
  # filter is a car id, :guest or :unassigned (see CarSelection#filter).
  scope :list_for,
        lambda { |kind, timeframe: nil, filter: nil|
          scope = where(kind:)
          scope = scope.where(started_at: timeframe.beginning..timeframe.ending) if timeframe && !timeframe.all?
          scope =
            case filter
            when :unassigned then scope.unassigned
            when :guest then scope.where(guest: true)
            when Integer then scope.where(car_id: filter)
            else scope
            end

          scope.joined.order(started_at: :desc)
        }

  # The list opens with the wallbox sessions, or with the offsite sessions
  # without a wallbox
  def self.default_kind
    Sensor::Config.exists?(:wallbox_power) ? 'wallbox' : 'offsite'
  end

  # The kinds that the list offers. Without a wallbox, the wallbox sessions
  # of an earlier wallbox stay as history, so their list stays too.
  def self.listed_kinds
    kinds.keys.select { it != 'wallbox' || Sensor::Config.exists?(:wallbox_power) || wallbox.exists? }
  end

  # The Sums of the sessions of the scope
  def self.sums
    ChargingSession::Sums.from_row(with_continued.pick(*ChargingSession::Sums.sql))
  end

  # { [car id, guest, local date, kind] => Sums } of the sessions of the
  # scope. The local date is the same day as #date. The rows grow with the
  # days, not with the sessions.
  def self.daily_sums
    columns = [:car_id, :guest, Arel.sql('local_date'), :kind]

    with_continued.group(*columns).pluck(*columns, *ChargingSession::Sums.sql).to_h do |row|
      [row.first(columns.size), ChargingSession::Sums.from_row(row.drop(columns.size))]
    end
  end

  # The detection cuts a charge over midnight into one session for each day
  # (see ChargingSession::Detection). The user sees one charge, so the list
  # joins these sessions again, and a count counts the charge once.
  #
  # A session continues the session before it when both have the same kind
  # and holder, it starts on another day, and the gap between them does not
  # end a period of the detection (see ChargingSession::Detection::Periods).
  # Only the sessions of the scope count, so a charge at the edge of a
  # timeframe shows its part in the timeframe.
  #
  # The sessions of the scope with the column `continued`: whether a session
  # continues the session before it, and the column `local_date`: the local
  # date of its start
  def self.with_continued
    dated = select(arel_table[Arel.star], local_date_sql.as('local_date'))
    continued = unscoped.from(dated, table_name).select(
      "#{table_name}.*",
      sanitize_sql_array([CONTINUED_SQL, { gap: ChargingSession::Detection::Periods::GAP.to_i }]),
    )

    unscoped.from(continued, table_name)
  end

  # The charges of the scope: the sessions of a charge joined into one
  # record with the id of its first session. `part_ids` gives the sessions
  # in the order of time. A sum is missing when a part misses it, like the
  # cost on a day without a price. Only a wallbox session continues another
  # one, so the columns of an offsite session have one value each.
  def self.joined
    numbered = unscoped.from(with_continued, table_name).select("#{table_name}.*", Arel.sql(CHARGE_NUMBER_SQL))
    charges = unscoped.from(numbered, table_name).select(*CHARGE_COLUMNS).group(:kind, :car_id, :guest, :charge_number)

    unscoped.from(charges, table_name)
  end

  # The local date of the start in SQL
  def self.local_date_sql
    Arel.sql("(started_at AT TIME ZONE 'UTC' AT TIME ZONE #{connection.quote(Time.zone.tzinfo.name)})::date")
  end
  private_class_method :local_date_sql

  # The charge of this session (see .joined)
  def charge
    self.class.where(kind:, car_id:, guest:).joined.find_by!('? = ANY(part_ids)', id)
  end

  # Changes each session of a charge (see .joined) with the attributes. The
  # head of the charge keeps the note, so the joined note does not repeat
  # it. The errors of a part become the errors of the charge.
  def update_parts(attributes) # rubocop:disable Naming/PredicateMethod
    assign_attributes(attributes)
    parts = self.class.where(id: part_ids).order(:started_at).to_a

    self.class.transaction do
      parts.each_with_index do |part, index|
        part_attributes = index.zero? || !attributes.key?(:note) ? attributes : attributes.merge(note: nil)
        next if part.update(part_attributes)

        errors.merge!(part.errors)
        raise ActiveRecord::Rollback
      end
    end

    errors.empty?
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
