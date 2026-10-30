# The rows of one page of the payments (see Car::PaymentList::Component),
# with a header above the payments of each year (see Ui::YearGroups)
class Car::PaymentList::Rows::Component < ViewComponent::Base
  # Each page of the list loads into a Turbo frame of its own (see Ui::LazyRows)
  FRAME_PREFIX = 'car_payments_page_'.freeze
  public_constant :FRAME_PREFIX

  # `previous_date`: see Ui::YearGroups
  def initialize(payments:, pagy:, car_column:, filter:, previous_date: nil, frame: false)
    super()
    @groups = Ui::YearGroups.new(payments, previous_date:)
    @pagy = pagy
    @car_column = car_column
    @filter = filter
    @frame = frame
  end

  def call
    render Ui::LazyRows::Component.new(prefix: FRAME_PREFIX, pagy: @pagy, frame: @frame) do
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

  def row(payment) = render Car::PaymentList::Row::Component.new(payment:, filter: @filter, car_column: @car_column)
end
