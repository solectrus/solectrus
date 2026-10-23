# The list of the charging sessions, a page below the car page: a head
# with the switch of the kinds, the sums of the kind and, for the offsite
# sessions of the admin, the button of their map. Below, a table on the
# desktop and a grouped list on a phone, grouped by week or month (see
# Ui::RowGroups), and a next page that loads when it comes into view.
#
# The sums are the sessions that count, like the chart above. The admin also
# sees the sessions to review in the list, which the sums leave out (see
# ChargingSession::Review). An amber link beside the sums names their number
# and shows them alone, with a sentence about what to do with them. It is an
# amber button with an x then, which shows each session again.
class ChargingSession::List::Component < ViewComponent::Base
  # The switch of the sessions to review: their number, whether the list
  # shows them alone, and the list the other way
  ReviewSwitch = Data.define(:number, :on, :href)
  public_constant :ReviewSwitch

  # `selection` is the car of the page (see CarSelection). `kinds` are the
  # items of the switch, empty for one kind. `map_path` opens the map of the
  # sessions, or is nil. `review` is the switch of the sessions to review,
  # or nil.
  def initialize(charging_sessions:, kind:, selection:, pagy: nil, timeframe: nil, kinds: [], map_path: nil, review: nil) # rubocop:disable Metrics/ParameterLists
    super()
    @charging_sessions = charging_sessions
    @kind = kind
    @selection = selection
    @pagy = pagy
    @timeframe = timeframe
    @kinds = kinds
    @map_path = map_path
    @review = review
  end

  attr_reader :charging_sessions, :kind, :pagy, :timeframe, :kinds, :review

  # The map shows the sessions that count, like the sums, so a list of
  # proposals alone has nothing to show on it
  def map_path = (@map_path if totals.any?)

  def review_only? = review&.on

  def sessions
    @sessions ||= charging_sessions.to_a
  end

  # The Sums of the sessions that count, of the whole list and not only of
  # its first page
  def totals
    @totals ||= ChargingSession.list_for(kind, timeframe:, filter: @selection.filter).reorder(nil).sums
  end

  # The sums in one line: the sessions, the energy and the cost. They stay
  # while the list shows the sessions to review alone, whose switch names
  # their number, so the head keeps its layout. Without a session that
  # counts, like a list of proposals alone, the sums would be 0, and an
  # empty list says so below.
  def totals_text
    return if totals.none?

    parts = [
      "#{totals.count} #{t('charging_sessions.count', count: totals.count)}",
      Sensor::ValueFormatter.new(totals.kwh * 1000, unit: Sensor::Registry[:wallbox_power].unit, context: :total, scaling: :kilo).to_s,
      (cost_text if totals.cost?),
    ]
    parts.compact.join(' · ')
  end

  # A cost without the cost of each session is a minimum, which the sums
  # explain
  def totals_note = (t('charging_sessions.cost_incomplete') if totals.any? && totals.cost? && !totals.costed?)

  # The text of an empty list names the selection: the guest, one car, or
  # the sessions of the kind
  def empty_title
    if @selection.guest?
      t('charging_sessions.empty.guest')
    elsif @selection.car
      t("charging_sessions.empty.#{kind}_of", car: @selection.car.display_name)
    else
      t("charging_sessions.empty.#{kind}")
    end
  end

  def empty_text = t(@selection.guest? ? 'charging_sessions.description.guest' : "charging_sessions.description.#{kind}")

  # The list of the proposals alone dismisses them at once, for a time
  # without receipts (see #6021)
  def dismiss_all? = review_only? && kind == 'offsite' && review.number.positive?

  # The text of the switch of the sessions to review, like "3 unconfirmed",
  # with the number in bold, like the sums beside it
  def review_label
    text = t("charging_sessions.open.#{kind}", count: review.number)
    number = review.number.to_s
    safe_join([tag.span(number, class: 'font-bold'), text.delete_prefix(number)])
  end

  REVIEW_CLASS = 'inline-flex items-center gap-1.5 h-7 rounded-full text-sm lg:text-base whitespace-nowrap tabular-nums focus-ring click-animation'.freeze
  REVIEW_OFF_CLASS = 'px-1 text-attention-strong hover:underline underline-offset-4'.freeze
  REVIEW_ON_CLASS = 'px-2.5 bg-attention text-on-attention hover:brightness-110'.freeze
  private_constant :REVIEW_CLASS, :REVIEW_OFF_CLASS, :REVIEW_ON_CLASS

  # The columns of the table from lg up: the day, the time, the car, the
  # energy, the state of charge, the place or the PV share, and the cost
  GRID_COLUMNS = 'lg:grid-cols-[auto_auto_auto_auto_auto_minmax(0,1fr)_auto]'.freeze
  public_constant :GRID_COLUMNS

  private

  # A wallbox session has no cost on a day without a price, so the total
  # cost is a minimum
  def cost_text
    cost = number_to_currency(totals.cost, unit: Currency.symbol)
    totals.costed? ? cost : "≥ #{cost}"
  end
end
