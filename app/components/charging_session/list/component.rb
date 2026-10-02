class ChargingSession::List::Component < ViewComponent::Base
  # `filter` is the car filter of the list (see ChargingSessionList::CarFilter)
  def initialize(charging_sessions:, kind:, pagy: nil, timeframe: nil, filter: ChargingSessionList::CarFilter.new(nil))
    super()
    @charging_sessions = charging_sessions
    @kind = kind
    @pagy = pagy
    @timeframe = timeframe
    @filter = filter
  end

  attr_reader :charging_sessions, :kind, :pagy, :timeframe, :filter

  def sessions
    @sessions ||= charging_sessions.to_a
  end

  def total_kwh
    totals[:kwh]
  end

  def total_count
    totals[:count]
  end

  def total_cost
    totals[:cost]
  end

  # A wallbox session has no cost on a day without a price, so the total
  # cost is too small
  def cost_incomplete?
    totals[:without_cost].positive?
  end

  def pv_share?
    helpers.pv_share_column?(kind)
  end

  # PV share of all sessions, nil when a session has no grid share
  def total_pv_percent
    return if totals[:without_split].positive? || total_kwh.zero?

    ((total_kwh - totals[:kwh_grid]) * 100 / total_kwh).round
  end

  def empty_message
    if timeframe.nil? || timeframe.all?
      I18n.t("charging_sessions.empty.#{kind}.all")
    else
      I18n.t("charging_sessions.empty.#{kind}.filtered", timeframe: timeframe.localized)
    end
  end

  private

  def totals
    @totals ||= ChargingSession.list_for(kind, timeframe:, filter: filter.scope_value).reorder(nil).totals
  end
end
