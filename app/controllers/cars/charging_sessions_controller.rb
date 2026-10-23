# The list of the charging sessions, a page below the car page: the wallbox
# sessions or the offsite sessions of the selected car (see
# Cars::ChargingSessionListing). The offsite sessions also have their map over the
# list, and the admin edits a session in its form.
class Cars::ChargingSessionsController < ApplicationController
  include CarListPage
  include FormPageResponse
  include BelowMore
  include Cars::ChargingSessionListing

  # A guest reads the list too, without its open tasks and its forms (see
  # Cars::ChargingSessionListing).
  skip_before_action :admin_required!, only: :index

  before_action :load_charging_session, only: %i[edit update destroy dismiss]
  before_action :new_charging_session, only: %i[new create]

  def index
    # An unknown kind goes to the list of the default kind in the timeframe
    return redirect_to(charging_page_path(listed_kinds.first)) unless params.key?(:kind) && kind.in?(listed_kinds)

    # A car that the page does not offer goes to "all", like on the car page.
    # The sessions to review that no car narrows are in "all" alone.
    return redirect_to(cars_charging_sessions_path(kind:, timeframe: timeframe.to_param, car: nil, review: params[:review])) if !car_selection.valid? || review_of_all?

    return render_next_page if next_page?

    # While days wait for the detection, the page shows the build instead of the list
    @missing_or_stale_summary_days = pending_days
  end

  def new
  end

  # The form of an offsite session opens without Nominatim, and asks it once
  # it opened, if necessary (see ChargingSession::AddressLookup#prepare)
  def edit
    mark_ongoing(@charging_session.kind, [@charging_session])
    return unless @charging_session.offsite?

    lookup = ChargingSession::AddressLookup.new(@charging_session)
    lookup.prepare
    @address_pending = lookup.pending?
  end

  # The lookup of the address asks Nominatim before the save, so no
  # transaction of the database waits for it (see
  # ChargingSession::AddressLookup)
  def create = respond_to_save(@charging_session, ChargingSession::AddressLookup.new(@charging_session).save)

  def update = respond_to_save(@charging_session, save_changes)

  # A proposal keeps its row, so the next build does not make it again (see
  # ChargingSession::Proposal)
  def dismiss
    return head(:unprocessable_content) unless @charging_session.proposal?

    @charging_session.dismiss!
    respond_with_list(notice: t('charging_sessions.proposal.dismissed'))
  end

  # The proposals of the list go at once, for a time without receipts. Only
  # the proposals that the list showed go: a proposal of a later build stays.
  def dismiss_all
    return head(:unprocessable_content) unless return_to && listed_at

    count = ChargingSession.listed('offsite', timeframe:, filter: car_selection.filter, open: true).proposals.where(created_at: ..listed_at).dismiss_all
    respond_with_list(notice: t('charging_sessions.proposal.dismissed_all', count:))
  end

  # Only an offsite session can go (see ChargingSession)
  def destroy
    return head(:unprocessable_content) unless @charging_session.destroy

    respond_with_list(notice: t('crud.deleted'))
  end

  private

  def next_page? = Ui::LazyRows::Component.request?(request, ChargingSession::Rows::Component::FRAME_PREFIX)

  # The tab of this list (see CarListPage#list_tabs)
  def list_tab = :charging_sessions

  # The rows of a next page of the list
  def render_next_page
    pagy, sessions = pagy(:countless, listed_sessions(kind))
    mark_ongoing(kind, sessions)
    previous_started_at = listed_sessions(kind).offset(pagy.offset - 1).pick(:started_at)

    render ChargingSession::Rows::Component.new(sessions:, pagy:, timeframe:, previous_started_at:, frame: true), layout: false
  end

  # The days of the timeframe without a fresh summary, and so without their
  # sessions (see Summary::Builder::Component). Without a state of charge,
  # the offsite sessions come from the user alone.
  def pending_days
    return [] if timeframe.now? || (kind == 'offsite' && !ChargingSession::OffsiteDetection.enabled?)

    Sensor::Summarizer.build_few(Summary.missing_or_stale_days_for(timeframe))
  end

  # Refresh the list straight from the mutating request, so it does not depend
  # on a Turbo broadcast (which could not know the viewer's timeframe). The
  # timeframe, the car and the kind come from the page that opened the form
  # (see #list_source).
  def list_stream = turbo_stream.update('list', charging_list_component(kind))

  # The list of the timeframe and the car of the form, for a form that no
  # list opened (see FormPageResponse)
  def default_list_path = charging_page_path(kind)

  # The list of a kind in the timeframe and with the car of this list, with
  # its sessions to review alone or not
  def charging_page_path(kind, review: review_only?)
    cars_charging_sessions_path(kind:, timeframe: timeframe.to_param, car: car_selection.to_param, review: ('1' if review))
  end

  # The admin can narrow the list to its sessions to review, with the switch
  # in its head (see ChargingSession::Review)
  helper_method def review_only? = admin? && list_source[:review].present?

  # Whether the list shows the sessions to review of a car, which no car
  # narrows (see ChargingSession.review_by_car?)
  def review_of_all? = review_only? && car_selection.to_param && !ChargingSession.review_by_car?(kind)

  # Where the timeframe, the car and the kind come from: the address of the
  # list itself, or the list that opened the form (see
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

  # The car of the list: one car, all or the guest (see CarSelection)
  helper_method def car_selection
    @car_selection ||= CarSelection.new(list_source[:car], timeframe:, guest: true)
  end

  # The way back leads to the car page, in the timeframe and with the car of
  # the page
  helper_method def back_path
    cars_home_path(sensor_name: nil, timeframe: timeframe.to_param, car: car_selection.to_param)
  end

  # The list shows the sessions of the hours, unlike the car page
  helper_method def timeframe_page
    TimeframePage::List.new(route: :cars_charging_sessions_path, params: { kind:, car: car_selection.to_param, review: ('1' if review_only?) }, hours: true)
  end

  # The list offers a new offsite session to the admin. It needs a car (see
  # #prefilled_session), so the guest has none.
  helper_method def add_entry
    return unless admin? && car_selection.installed.any? && !car_selection.guest?

    { href: new_cars_charging_session_path(return_to: list_address), label: t('charging_sessions.new') }
  end

  helper_method def list_box = charging_list_component(kind)

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
    params.expect(charging_session: %i[car_id started_at ended_at kwh cost power_type evse_id provider address address_of_position latitude longitude note]).merge(kind: 'offsite')
  end

  # The kind of the list in its address, or of the list that sent the
  # request (see #list_source)
  helper_method def kind
    params[:kind] || list_source[:kind] || ChargingSession.listed_kinds.first
  end

  # A wallbox session changes each session of its charge. An offsite session
  # looks up its address before the save (see #create).
  def save_changes
    return @charging_session.update_parts(update_params) if @charging_session.wallbox?

    @charging_session.assign_attributes(update_params)
    ChargingSession::AddressLookup.new(@charging_session).save
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
  # reaches today the start is now,
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
