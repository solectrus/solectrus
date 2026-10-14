class Cars::ChargingSessionsController < ApplicationController
  include Pagy::Method
  include CarListPage
  include FormPageResponse

  before_action :load_charging_session, only: %i[edit update destroy dismiss]
  before_action :new_charging_session, only: %i[new create]

  def index
    # An unknown kind goes to the list of the default kind in the timeframe
    return redirect_to(cars_charging_sessions_path(kind: ChargingSession.default_kind, timeframe: timeframe.to_param)) unless kind.in?(ChargingSession.kinds.keys)

    # A car that the filter does not offer goes to "all", like on the car page
    return redirect_to(cars_charging_sessions_path(kind:, timeframe: timeframe.to_param, car: nil)) unless car_selection.valid?

    next_page = LazyRows::Component.request?(request, ChargingSession::Rows::Component::FRAME_PREFIX)

    # While days wait for the detection, the page shows the build instead of the list
    @missing_or_stale_summary_days = pending_days unless next_page
    return if @missing_or_stale_summary_days.present?

    @pagy, @charging_sessions = pagy(:countless, list_scope)
    mark_ongoing(@charging_sessions)
    return unless next_page

    render ChargingSession::Rows::Component.new(sessions: @charging_sessions, pagy: @pagy, frame: true), layout: false
  end

  def new
  end

  # An offsite session can have a position from the build, and the form
  # offers its address
  def edit
    charging_session = @charging_session
    mark_ongoing([charging_session])
    return unless charging_session.offsite? && charging_session.latitude && charging_session.address.blank?

    charging_session.address = Place.address_at(charging_session.latitude, charging_session.longitude)
  end

  def create = respond_to_save(@charging_session, @charging_session.save)

  def update = respond_to_save(@charging_session, save_changes)

  # A proposal keeps its row, so the next build does not make it again (see
  # ChargingSession::Proposal)
  def dismiss
    return head(:unprocessable_content) unless @charging_session.proposal?

    @charging_session.dismiss!
    respond_with_list(notice: t('charging_sessions.proposal.dismissed'))
  end

  # The proposals of the timeframe of the list go at once, for a time
  # without receipts. Only the list of the proposals offers it, and only the
  # proposals that the list showed go: a proposal of a later build stays.
  def dismiss_all
    return head(:unprocessable_content) unless car_selection.filter == :proposals && listed_at

    count = ChargingSession.in_timeframe(timeframe).where(created_at: ..listed_at).dismiss_all
    respond_with_list(notice: t('charging_sessions.proposal.dismissed_all', count:))
  end

  # Only an offsite session can go (see ChargingSession)
  def destroy
    return head(:unprocessable_content) unless @charging_session.destroy

    respond_with_list(notice: t('crud.deleted'))
  end

  private

  # The days of the timeframe without a fresh summary, and so without their
  # sessions. The page builds them first, like the car page (see
  # SummaryBuilder::Component).
  # Without a state of charge, the offsite sessions come from the user alone.
  def pending_days
    return [] if timeframe.now? || (kind == 'offsite' && !ChargingSession::OffsiteDetection.enabled?)

    Summary.missing_or_stale_days_for(timeframe)
  end

  # Only a wallbox list up to now can hold an ongoing session
  def mark_ongoing(sessions)
    ChargingSession.mark_ongoing(sessions) if kind == 'wallbox' && !timeframe.past?
  end

  def list_scope
    ChargingSession.list_for(kind, timeframe:, filter: car_selection.filter).includes(:car)
  end

  # Refresh the list straight from the mutating request, so it does not depend
  # on a Turbo broadcast (which could not know the viewer's timeframe). The
  # timeframe and the car filter come from the list that opened the form (see
  # #list_source). The list starts over at page 1, its follow-up pages load
  # from the path of the list, without the query of its address.
  def list_stream
    pagy, charging_sessions =
      pagy(
        :countless,
        list_scope,
        request: {
          base_url: request.base_url,
          path: URI(list_path).path,
          params: {},
        },
      )
    mark_ongoing(charging_sessions)

    turbo_stream.update(
      'list',
      ChargingSession::List::Component.new(charging_sessions:, pagy:, kind:, timeframe:, selection: car_selection),
    )
  end

  # The list of the timeframe and the car filter of the form, for a form that
  # no list opened (see FormPageResponse)
  def default_list_path
    cars_charging_sessions_path(kind:, timeframe: timeframe.to_param, car: car_selection.to_param)
  end

  # Where the timeframe and the car filter come from: the address of the list
  # itself, or the list that opened the form (see
  # FormPageResponse#return_to_params). So a change renders the list of its
  # own page, also with a second page in another tab.
  def list_source
    @list_source ||= action_name == 'index' ? params : return_to_params('cars/charging_sessions')
  end

  def timeframe_param = list_source[:timeframe]

  # When the list showed the proposals (see ChargingSession::List::Component)
  def listed_at
    @listed_at ||= Time.zone.iso8601(params[:listed_at].to_s)
  rescue ArgumentError
    nil
  end

  # The car filter of the list: one car, all, and the extras of the kind (see
  # CarSelection::EXTRAS)
  helper_method def car_selection
    @car_selection ||=
      CarSelection.new(list_source[:car], timeframe:, extras: true)
  end

  helper_method def title
    ChargingSession.human_enum_name(:kind, kind)
  end

  # The car page in the timeframe of the list. It keeps one car and the
  # guests, but not "not assigned", which the car page does not select.
  helper_method def back_path
    car = car_selection.extra == CarSelection::GUEST ? CarSelection::GUEST : car_selection.car&.id
    cars_home_path(sensor_name: 'car_charging', timeframe: timeframe.to_param, car:)
  end

  helper_method def timeframe_page
    # The list shows the sessions of the hours, unlike the car page
    TimeframePage::List.new(route: :cars_charging_sessions_path, params: { kind:, car: car_selection.to_param }, hours: true)
  end

  # The segments of a phone take the short name, as the card of the car page
  # that links here
  helper_method def nav_items(short: false)
    ChargingSession.listed_kinds.map do |k|
      {
        name: short ? t("car_breakdown.#{k}_short") : ChargingSession.human_enum_name(:kind, k),
        href: cars_charging_sessions_path(kind: k, timeframe:, car: car_selection.to_param_for(k)),
        current: kind == k,
      }
    end
  end

  # The detection writes energy, time and cost of a wallbox session, so the
  # user changes who charged and the note alone. The car field carries the
  # holder (see ChargingSession#holder).
  def update_params
    return permitted_params unless @charging_session.wallbox?

    attributes = params.expect(charging_session: %i[car_id note])
    attributes.except(:car_id).merge(holder: attributes[:car_id])
  end

  # A new session is an offsite session. A guest charge that no wallbox
  # measured has no energy and no cost.
  def permitted_params
    params.expect(charging_session: %i[car_id started_at ended_at kwh cost power_type evse_id provider address note]).merge(kind: 'offsite')
  end

  # The kind of the list, of the session, or of the list that sent the
  # request (see #list_source)
  helper_method def kind
    params[:kind] || @charging_session&.kind || list_source[:kind]
  end

  # A wallbox session changes each session of its charge
  def save_changes
    return @charging_session.update_parts(update_params) if @charging_session.wallbox?

    @charging_session.update(update_params)
  end

  # A wallbox session opens with its charge, so a charge over midnight
  # changes as one (see ChargingSession.joined)
  def load_charging_session
    charging_session = ChargingSession.find(params.expect(:id))
    @charging_session = charging_session.wallbox? ? charging_session.charge : charging_session
  end

  def new_charging_session
    @charging_session =
      if action_name == 'new'
        prefilled_session
      else
        ChargingSession.new(permitted_params.merge(origin: 'user'))
      end
  end

  # The car of the list, or the first car of its timeframe. In a list that
  # reaches today the start is now, as a new event in the calendar of iOS,
  # and the first car is one in use today. A start in a past list would offer
  # only the cars of today. A car of the list that is no longer in use keeps
  # the start empty.
  def prefilled_session
    today = Date.current unless timeframe.past? || timeframe.future?
    car = prefilled_car(today)
    started_at = Time.current.beginning_of_minute if today && car&.active_on?(today)

    ChargingSession.new(kind: 'offsite', car:, started_at:)
  end

  def prefilled_car(today)
    car_selection.car ||
      (car_selection.offered.find { it.active_on?(today) } if today) ||
      car_selection.offered.first ||
      car_selection.installed.first
  end
end
