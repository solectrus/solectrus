class ChargingSession::List::Component < ViewComponent::Base
  # `selection` is the car filter of the list (see CarSelection)
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

  # The key of the empty list: its kind, or the proposals
  def empty_key = @selection.filter == :proposals ? 'proposals' : kind

  # The add button of mobile, with a label. Desktop has it in the header.
  def add_button
    ChargingSession::AddButton::Component.new(
      kind:,
      selection: @selection,
      label: true,
      css_class: 'flex lg:landscape:hidden w-full gap-2 mb-3 py-2.5 rounded-md border border-dashed border-gray-300 dark:border-gray-600 text-sm font-medium text-gray-600 dark:text-gray-300 hover:bg-gray-50 dark:hover:bg-gray-800 focus-ring',
    )
  end

  def pv_share?
    helpers.pv_share_column?(kind)
  end
end
