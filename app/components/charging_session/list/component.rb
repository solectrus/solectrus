class ChargingSession::List::Component < ViewComponent::Base
  # `selection` is the car filter of the list (see CarSelection)
  # The list of wallbox sessions shows the PV share instead of the address,
  # when the power splitter gives the grid share
  def self.pv_share_column?(kind)
    kind.to_s == 'wallbox' && Sensor::Config.exists?(:wallbox_power_grid)
  end

  def initialize(charging_sessions:, kind:, selection:, pagy: nil, timeframe: nil)
    super()
    @charging_sessions = charging_sessions
    @kind = kind
    @selection = selection
    @pagy = pagy
    @timeframe = timeframe
  end

  attr_reader :charging_sessions, :kind, :pagy, :timeframe

  def sessions
    @sessions ||= charging_sessions.to_a
  end

  # The Sums of all sessions of the list, not only of its first page
  def totals
    @totals ||= ChargingSession.effective.list_for(kind, timeframe:, filter: @selection.filter).reorder(nil).sums
  end

  # A proposal does not count, so the list can show more rows than this
  def totals? = totals.count > 1 # rubocop:disable Style/CollectionQuerying

  # A wallbox session has no cost on a day without a price, so the total
  # cost is too small
  def cost_incomplete? = !totals.costed?

  def proposals? = @selection.filter == :proposals

  # The proposals of the whole list, not only of its first page. They do not
  # count, so their row has the number instead of the sums.
  def proposal_count
    @proposal_count ||= ChargingSession.proposals.in_timeframe(timeframe).count
  end

  # The key of the empty list: its kind, or the proposals
  def empty_key = proposals? ? 'proposals' : kind

  def pv_share?
    self.class.pv_share_column?(kind)
  end

  # The columns of the table from lg up: the PV share takes the wide column
  # after the energy, the address the one before it
  def grid_columns
    pv_share? ? 'lg:grid-cols-[auto_auto_auto_auto_1fr_auto]' : 'lg:grid-cols-[auto_auto_auto_1fr_auto_auto]'
  end
end
