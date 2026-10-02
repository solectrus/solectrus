class ChargingSessionsController < ApplicationController
  include Pagy::Method

  before_action :admin_required!

  before_action :load_charging_session, only: %i[edit update destroy]
  before_action :new_charging_session, only: %i[new create]

  def index
    unless kind.in?(ChargingSession.kinds.keys)
      redirect_to charging_sessions_path(kind: ChargingSession.default_kind)
      return
    end

    remember_list
    next_page = request.headers['Turbo-Frame']&.start_with?(ChargingSession::Rows::Component::FRAME_PREFIX)

    # While days wait for the detection, the page shows the build instead of the list
    @missing_or_stale_summary_days = pending_days unless next_page
    return if @missing_or_stale_summary_days.present?

    @pagy, @charging_sessions = pagy(:countless, list_scope)
    return unless next_page

    render ChargingSession::Page::Component.new(
             sessions: @charging_sessions,
             pagy: @pagy,
           ),
           layout: false
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
    if @charging_session.update(update_params)
      render_list
    else
      render :edit, status: :unprocessable_content
    end
  end

  # The detection writes each wallbox session again, so only an offsite
  # session can go.
  def destroy
    return head(:unprocessable_content) unless @charging_session.offsite?

    @charging_session.destroy!
    render_list
  end

  private

  # The days of the timeframe whose sessions wait for the detection. The
  # page builds them first, like the car page (see SummaryBuilder::Component).
  def pending_days
    return [] if timeframe.now? || kind != 'wallbox'

    Summary.missing_or_stale_days_for(timeframe, charging_sessions: true)
  end

  def list_scope
    ChargingSession.list_for(kind, timeframe:, filter: car_filter.scope_value).includes(:car)
  end

  # Refresh the list straight from the mutating request, so it does not depend
  # on a Turbo broadcast (which could not know the viewer's timeframe). The
  # list starts over at page 1, its follow-up pages load from the index URL.
  def render_list
    flash.now[:notice] = t('crud.success')

    pagy, charging_sessions =
      pagy(
        :countless,
        list_scope,
        request: {
          base_url: request.base_url,
          path: charging_sessions_path(kind:, timeframe:, car: car_param),
          params: {},
        },
      )

    render turbo_stream: [
             turbo_stream.update(
               'list',
               ChargingSession::List::Component.new(
                 charging_sessions:,
                 pagy:,
                 kind:,
                 timeframe:,
                 filter: car_filter,
               ),
             ),
             turbo_stream_update_flash,
           ]
  end

  # Persist the timeframe and the car filter the index is currently showing,
  # so a later mutation (which carries neither) can re-apply the same ones.
  def remember_list
    session[:charging_session_timeframe] = timeframe.to_param
    session[:charging_session_car] = car_param
  end

  def mutation?
    action_name.in?(%w[create update destroy])
  end

  def timeframe_param
    mutation? ? session[:charging_session_timeframe] : params[:timeframe]
  end

  helper_method def car_filter
    @car_filter ||=
      ChargingSessionList::CarFilter.from_param(
        mutation? ? session[:charging_session_car] : params[:car],
        cars:,
      )
  end

  helper_method def car_param = car_filter.to_param

  helper_method def cars
    @cars ||= Car::Provisioning.call.to_a
  end

  helper_method def title
    ChargingSession.human_enum_name(:kind, kind)
  end

  helper_method def nav_items
    ChargingSession.kinds.keys.map do |k|
      {
        name: ChargingSession.human_enum_name(:kind, k),
        href: charging_sessions_path(kind: k, timeframe:, car: car_filter.to_param_for(k)),
        current: kind == k,
      }
    end
  end

  # The detection writes energy, time and cost of a wallbox session, so the
  # user changes its car, its guest mark and its note alone. The car field
  # carries ChargingSessionList::CarFilter::GUEST for a guest charge and nothing for "not assigned".
  def update_params
    return permitted_params unless @charging_session.wallbox?

    attributes = params.expect(charging_session: %i[car_id note])
    guest = attributes[:car_id] == ChargingSessionList::CarFilter::GUEST
    attributes.merge(car_id: (attributes[:car_id] unless guest).presence, guest:)
  end

  # A new session is an offsite session. A guest charge that no wallbox
  # measured has no energy and no cost.
  def permitted_params
    params.expect(charging_session: %i[car_id started_at ended_at kwh cost power_type evse_id provider address note]).merge(kind: 'offsite')
  end

  helper_method def kind
    params[:kind] || @charging_session&.kind
  end

  helper_method def timeframe
    @timeframe ||= Timeframe.new(timeframe_param.presence || 'all')
  rescue ArgumentError
    @timeframe = Timeframe.new('all')
  end

  def load_charging_session
    @charging_session = ChargingSession.find(params.expect(:id))
  end

  def new_charging_session
    @charging_session =
      if action_name == 'new'
        ChargingSession.new(kind: 'offsite', car: cars.first)
      else
        ChargingSession.new(permitted_params)
      end
  end
end
