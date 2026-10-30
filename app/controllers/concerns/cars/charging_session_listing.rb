# The list of the charging sessions, with its pages and its refresh after a
# save (see Cars::ChargingSessionsController). The controller gives
# `car_selection`, `timeframe`, `review_only?`, `sheet_page?` (see SheetPage)
# and `charging_page_path`, the list of a kind.
module Cars::ChargingSessionListing
  extend ActiveSupport::Concern
  include Pagy::Method

  private

  # The sessions of the list. The admin also sees the sessions to review
  # (see ChargingSession.listed), or them alone. A visitor sees no session of
  # the days that only the admin sees (see Car::AdminOnlyDays).
  def listed_sessions(kind)
    ChargingSession.list_for(kind, timeframe:, filter: car_selection.filter, open: admin?, review: review_only?, public_only: !admin?).includes(:car)
  end

  # The list with its first page. Its next pages load from the list of the
  # sessions, without the query of the page.
  def charging_list_component(kind)
    pagy, sessions =
      pagy(
        :countless,
        listed_sessions(kind),
        request: { base_url: request.base_url, path: charging_page_path(kind), params: {} },
      )
    mark_ongoing(kind, sessions)

    ChargingSession::List::Component.new(
      charging_sessions: sessions,
      pagy:,
      kind:,
      timeframe:,
      selection: car_selection,
      kinds: charging_kind_items(kind),
      map_path: (charging_map_path if kind == 'offsite' && admin?),
      review: review_switch(kind),
      sheet: sheet_page?,
    )
  end

  # The switch of the sessions to review of the admin, while the list has
  # some, or nil
  def review_switch(kind)
    count = admin? ? ChargingSession.review_count(kind, timeframe:, filter: car_selection.filter) : 0
    return unless count.positive? || review_only?

    ChargingSession::List::Component::ReviewSwitch.new(number: count, on: review_only?, href: review_only? ? charging_page_path(kind, review: false) : review_path(kind))
  end

  # The list of the sessions to review of a kind. Where no car narrows them,
  # it is the list of "all" (see ChargingSession.review_by_car?).
  def review_path(kind)
    car = car_selection.to_param if ChargingSession.review_by_car?(kind)
    cars_charging_sessions_path(kind:, timeframe: timeframe.to_param, car:, review: '1')
  end

  # Only a wallbox list up to now can hold an ongoing session
  def mark_ongoing(kind, sessions)
    ChargingSession.mark_ongoing(sessions) if kind == 'wallbox' && !timeframe.past?
  end

  # The kinds of the list. A guest charges at the wallbox alone (see
  # ChargingSession#guest_without_car).
  def listed_kinds
    car_selection.guest? ? ChargingSession.listed_kinds & ['wallbox'] : ChargingSession.listed_kinds
  end

  # The kinds of the sessions, which switch the list. One kind needs no
  # switch. The other kind starts without the sessions to review alone. A
  # kind with sessions to review has a dot for the admin, so the other kind
  # shows that it has some too.
  def charging_kind_items(current)
    kinds = listed_kinds
    return [] if kinds.one?

    kinds.map do |kind|
      count = admin? ? ChargingSession.review_count(kind, timeframe:, filter: car_selection.filter) : 0
      { name: t("car_breakdown.#{kind}_short"), href: charging_page_path(kind, review: false), current: kind == current, note: (t("charging_sessions.open.#{kind}", count:) if count.positive?) }
    end
  end

  # The map of the offsite sessions over their list
  def charging_map_path = cars_charging_session_map_path(timeframe: timeframe.to_param, car: car_selection.to_param)
end
