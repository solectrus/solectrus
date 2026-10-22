class ChargingSession::Row::Component < ViewComponent::Base
  include ChargingSession::Texts

  def initialize(charging_session:)
    super()
    @charging_session = charging_session
  end

  attr_reader :charging_session

  # Where the session charged: its address, its provider or its note
  def location
    charging_session.address.presence || charging_session.provider.presence || charging_session.note
  end

  # The day of the session: on the car page for the session of a car or of
  # the guest, and on the power balance for a session that is not assigned,
  # which the car page does not select
  def day_path
    day = charging_session.date.iso8601
    if charging_session.car || charging_session.guest?
      helpers.cars_home_path(sensor_name: 'car_charging', timeframe: day, car: charging_session.car_id || CarSelection::GUEST)
    else
      helpers.balance_home_path(sensor_name: 'wallbox_power', timeframe: day)
    end
  end

  # The form keeps the address of the list, with its timeframe and its car
  # filter
  def edit_path
    helpers.edit_cars_charging_session_path(charging_session, return_to: helpers.list_address)
  end

  # The title of the page of the form on a phone, before it loads
  def nav_title
    t(charging_session.proposal? ? 'charging_sessions.proposal.title' : 'charging_sessions.edit')
  end

  # Whether the state of charge of the session contradicts its energy (see
  # ChargingSession::StateOfCharge#soc_mismatch?)
  def soc_mismatch?
    return @soc_mismatch if defined?(@soc_mismatch)

    @soc_mismatch = charging_session.soc_mismatch?
  end

  def soc_mismatch_hint
    "#{t('charging_sessions.soc_finding.mismatch.text').upcase_first}.\n\n#{t('charging_sessions.soc_finding.mismatch.hint')}"
  end

  def pv_share?
    ChargingSession::List::Component.pv_share_column?(charging_session.kind)
  end
end
