class Cars::ChargingSessionsController < ApplicationController
  include Pagy::Method
  include CarListPage

  before_action :load_charging_session, only: %i[edit update destroy]
  before_action :new_charging_session, only: %i[new create]

  def index
    return redirect_to(cars_charging_sessions_path(kind: ChargingSession.default_kind)) unless kind.in?(ChargingSession.kinds.keys)

    # A car that the filter does not offer goes to "all", like on the car page
    return redirect_to(cars_charging_sessions_path(kind:, timeframe: params[:timeframe], car: nil)) unless car_selection.valid?

    next_page = LazyRows::Component.request?(request, ChargingSession::Rows::Component::FRAME_PREFIX)

    # While days wait for the detection, the page shows the build instead of the list
    @missing_or_stale_summary_days = pending_days unless next_page
    return if @missing_or_stale_summary_days.present?

    @pagy, @charging_sessions = pagy(:countless, list_scope)
    return unless next_page

    render ChargingSession::Rows::Component.new(sessions: @charging_sessions, pagy: @pagy, frame: true), layout: false
  end

  def new
  end

  def edit
  end

  def create
    if @charging_session.save
      render_list
    else
      render :new, status: :unprocessable_content
    end
  end

  def update
    if save_changes
      render_list
    else
      render :edit, status: :unprocessable_content
    end
  end

  # Only an offsite session can go (see ChargingSession)
  def destroy
    return head(:unprocessable_content) unless @charging_session.destroy

    render_list
  end

  private

  # The days of the timeframe whose sessions wait for the detection. The
  # page builds them first, like the car page (see SummaryBuilder::Component).
  def pending_days
    return [] if timeframe.now? || kind != 'wallbox'

    Summary.missing_or_stale_days_for(timeframe, steps: [ChargingSession::Detection::KEY])
  end

  def list_scope
    ChargingSession.list_for(kind, timeframe:, filter: car_selection.filter).includes(:car)
  end

  # Refresh the list straight from the mutating request, so it does not depend
  # on a Turbo broadcast (which could not know the viewer's timeframe). The
  # form carries the timeframe and the car filter of its list (see
  # #list_params). The list starts over at page 1, its follow-up pages load
  # from the index URL.
  def render_list
    flash.now[:notice] = t('crud.success')

    pagy, charging_sessions =
      pagy(
        :countless,
        list_scope,
        request: {
          base_url: request.base_url,
          path: cars_charging_sessions_path(kind:, timeframe:, car: car_selection.to_param),
          params: {},
        },
      )

    render turbo_stream: [
             turbo_stream.update(
               'list',
               ChargingSession::List::Component.new(charging_sessions:, pagy:, kind:, timeframe:, selection: car_selection),
             ),
             turbo_stream_update_flash,
           ]
  end

  # The timeframe and the car filter of the list. Each link to a form and
  # each form carries them, so a change renders the list of its own page,
  # also with a second page in another tab.
  helper_method def list_params
    { timeframe: timeframe.to_param, car: car_selection.to_param }.compact
  end

  # The car filter of the list: one car, all, and the extras of the kind (see
  # CarSelection::EXTRAS)
  helper_method def car_selection
    @car_selection ||=
      CarSelection.new(params[:car], timeframe:, extras: true)
  end

  helper_method def title
    ChargingSession.human_enum_name(:kind, kind)
  end

  # The car page in the timeframe of the list. It keeps one car, but not a
  # guest or "not assigned", which the car page does not select.
  helper_method def back_path
    cars_home_path(sensor_name: 'car_charging', timeframe: timeframe.to_param, car: car_selection.car&.id)
  end

  helper_method def timeframe_page
    # The list shows the sessions of the hours, unlike the car page
    TimeframePage::List.new(route: :cars_charging_sessions_path, params: { kind:, car: car_selection.to_param }, hours: true)
  end

  helper_method def nav_items
    ChargingSession.listed_kinds.map do |k|
      {
        name: ChargingSession.human_enum_name(:kind, k),
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

  helper_method def kind
    params[:kind] || @charging_session&.kind
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
        # The car of the list, or the first car of its timeframe
        ChargingSession.new(kind: 'offsite', car: car_selection.car || car_selection.offered.first || car_selection.installed.first)
      else
        ChargingSession.new(permitted_params.merge(origin: 'user'))
      end
  end
end
