# The rows of one page of the payments (see PaymentList::Component), with a
# header above the payments of each year (see Ui::YearGroups)
class PaymentList::Rows::Component < ViewComponent::Base
  # Each page of the list loads into a Turbo frame of its own (see
  # Ui::LazyRows), named by the class of the payments, like
  # car_payments_page_2
  def self.frame_prefix(payment_class) = "#{payment_class.model_name.route_key}_page_"

  # `payment_class` names the frames. `previous_date`: see Ui::YearGroups
  def initialize(payments:, payment_class:, pagy:, car_column:, filter:, previous_date: nil, frame: false) # rubocop:disable Metrics/ParameterLists
    super()
    @prefix = self.class.frame_prefix(payment_class)
    @groups = Ui::YearGroups.new(payments, previous_date:)
    @pagy = pagy
    @car_column = car_column
    @filter = filter
    @frame = frame
  end

  def call
    render Ui::LazyRows::Component.new(prefix: @prefix, pagy: @pagy, frame: @frame) do
      safe_join(@groups.flat_map { |payment, year| [group_header(year), row(payment)] })
    end
  end

  private

  # A list of a single year needs no header. The header of a year narrows
  # the list to it.
  def group_header(year)
    return if year.nil? || @filter.year

    render Ui::GroupHeader::Component.new(title: year.to_s, href: helpers.filter_path(@filter.with_year(Date.new(year))))
  end

  def row(payment) = render PaymentList::Row::Component.new(payment:, filter: @filter, car_column: @car_column)
end
