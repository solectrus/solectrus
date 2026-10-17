# The list of the offsite sessions has a second view, the map (see
# ChargingSession::Map::Component). The wallbox sessions have none, because
# they share one place. The view stays in the address of the list as the
# segment `map` after the timeframe, so each link of the list keeps it. The menu of the filter
# switches between the views (see ChargingSession::Filter::Component).
module ChargingSessionsView
  extend ActiveSupport::Concern

  included do
    helper_method :filter_component, :list_component
    before_action :leave_map_without_map
  end

  private

  # The wallbox sessions have no map, so their map goes to their list
  def leave_map_without_map
    return if action_name != 'index' || params[:view].nil? || map_view?

    redirect_to(cars_charging_sessions_path(kind:, timeframe: timeframe.to_param, car: car_selection.to_param))
  end

  # The view comes from the address of the list (see #list_source)
  def map_view? = kind == 'offsite' && list_source[:view] == 'map'

  # The view in the address of each link of the list, nil for the list
  def view_param = ('map' if map_view?)

  # The filter of the cars, which holds the switch of the view for the offsite
  # sessions
  def filter_component(**)
    ChargingSession::Filter::Component.new(kind:, timeframe:, cars: car_selection.offered, current: car_selection.to_param, view: view_param, views: view_items, **)
  end

  # The switch between the list and the map, or nil for the wallbox sessions
  def view_items
    return unless kind == 'offsite'

    [[t('charging_sessions.view.list'), 'list', nil], [t('charging_sessions.view.map'), 'map', 'map']].map do |name, icon, view|
      {
        name:,
        icon:,
        href: cars_charging_sessions_path(kind:, timeframe: timeframe.to_param, car: car_selection.to_param, view:),
        current: view_param == view,
      }
    end
  end

  # The list or the map of the sessions. Without a session, the map shows the
  # empty list, which names the kind.
  def list_component(charging_sessions = [], pagy = nil)
    return map_component if map_view? && map_component.any?

    ChargingSession::List::Component.new(charging_sessions:, pagy:, kind:, timeframe:, selection: car_selection)
  end

  # The map loads the spots of the sessions alone, and each tooltip loads
  # its sessions (see Cars::SpotTooltipsController)
  def map_component
    @map_component ||= ChargingSession::Map::Component.new(
      scope: ChargingSession.listed(kind, timeframe:, filter: car_selection.filter),
      tooltip_url: cars_spot_tooltip_path(car: car_selection.to_param, spot: ':id', timeframe: timeframe.to_param),
    )
  end
end
