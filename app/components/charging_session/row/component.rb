# A charging session in the list of the charging sessions (see
# ChargingSession::List::Component): a row of the table from lg up, a cell of
# a grouped list below. The admin opens its form with a click on the row. A
# visitor reads the row alone, without the place of an offsite session.
class ChargingSession::Row::Component < ViewComponent::Base
  include ChargingSession::Texts

  def initialize(charging_session:)
    super()
    @charging_session = charging_session
  end

  attr_reader :charging_session

  delegate :admin?, to: :helpers

  # Where the session charged: home for the wallbox, else its address, its
  # provider or its note. The place of an offsite session is personal data,
  # so a visitor reads "offsite".
  def place
    return t('places.labels.home') if charging_session.wallbox?
    return t('car_breakdown.offsite_short') unless admin?

    charging_session.address.presence || charging_session.provider.presence || charging_session.note.presence || t('car_breakdown.offsite_short')
  end

  # The day of the session
  def date = l(charging_session.started_at.in_time_zone.to_date, format: :weekday)

  # The start of the session, or since when an ongoing session charges
  def start_time
    time = charging_session.started_at.in_time_zone.strftime('%H:%M')
    charging_session.ongoing? ? t('charging_sessions.since', time:) : time
  end

  # A dot that pulses while the session charges
  def ongoing_dot
    label = t('charging_sessions.ongoing')
    tag.span(class: 'relative flex size-2 shrink-0', role: 'img', title: label, aria: { label: }, data: { controller: 'tooltip' }) do
      tag.span(class: 'absolute inline-flex size-full rounded-full bg-signal-positive opacity-75 animate-ping motion-reduce:animate-none') +
        tag.span(class: 'relative inline-flex size-2 rounded-full bg-signal-positive')
    end
  end

  # The day of the session on the car page: for the session of a car or of
  # the guest the overview with the timeline of the day, and on the power
  # balance for a session that is not assigned, which the car page does not select
  def day_path
    day = charging_session.date.iso8601
    if charging_session.car || charging_session.guest?
      helpers.cars_home_path(timeframe: day, car: charging_session.car_id || CarSelection::GUEST)
    else
      helpers.balance_home_path(sensor_name: 'wallbox_power', timeframe: day)
    end
  end

  # The form keeps the address of the list, with its timeframe and its car.
  # Only the admin edits a session.
  def edit_path
    helpers.edit_cars_charging_session_path(charging_session, return_to: helpers.list_address) if admin?
  end

  # The title of the page of the form on a phone, before it loads
  def nav_title
    t(charging_session.proposal? ? 'charging_sessions.proposal.title' : 'charging_sessions.edit')
  end

  def energy = Sensor::Value::Component.new(charging_session.kwh * 1000, :wallbox_power, context: :total, scaling: :kilo)

  def cost = (number_to_currency(charging_session.cost, unit: Currency.symbol) if charging_session.cost)

  # Whether the state of charge of the session contradicts its energy (see
  # ChargingSession::StateOfCharge#soc_mismatch?)
  def soc_mismatch?
    return @soc_mismatch if defined?(@soc_mismatch)

    @soc_mismatch = charging_session.soc_mismatch?
  end

  def soc_mismatch_hint
    "#{t('charging_sessions.soc_finding.mismatch.text').upcase_first}.\n\n#{t('charging_sessions.soc_finding.mismatch.hint')}"
  end

  # An offsite session has no PV share
  def pv_percent = (charging_session.pv_percent&.round&.clamp(0, 100) if charging_session.wallbox?)

  # The columns of the cell on a phone. A wallbox session starts with the
  # ring of its PV share, an offsite session with its text.
  def phone_columns
    if charging_session.wallbox?
      { grid: 'max-lg:grid-cols-[auto_minmax(0,1fr)_auto_auto]', text: 'max-lg:col-start-2', value: 'max-lg:col-start-3' }
    else
      { grid: 'max-lg:grid-cols-[minmax(0,1fr)_auto_auto]', text: 'max-lg:col-start-1', value: 'max-lg:col-start-2' }
    end
  end
end
