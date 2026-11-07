# The payments of the cars or of the heat pump (see Payment): a grid on the
# desktop, whose rows open the form in the modal, and a grouped list on a
# phone, whose rows open the form on a page of its own (see
# Ui::TableRow::Component). An income shows as a positive amount, an
# expense as a negative one, and each payment names its category. The car
# has a column only with more than one car.
#
# The list shows a page of the payments and loads more while it scrolls
# (see Ui::LazyRows). The total is the sum of all payments of the filter,
# not only of the rows on the page.
class PaymentList::Component < ViewComponent::Base
  # `payment_class` is the class of the payments, like Car::Payment. `cars`
  # are the cars of the payments of the cars, none for the heat pump.
  def initialize(payments:, payment_class:, pagy:, total:, filter:, cars: [])
    super()
    @payments = payments
    @payment_class = payment_class
    @pagy = pagy
    @total = total
    @cars = cars
    @filter = filter
  end

  attr_reader :payments, :payment_class, :pagy, :total, :filter

  def car_column? = @cars.many?

  # The columns of the grid: the date, the car, the category, the note and
  # the amount
  def grid_columns
    car_column? ? 'grid-cols-[auto_auto_auto_minmax(0,1fr)_auto]' : 'grid-cols-[auto_auto_minmax(0,1fr)_auto]'
  end

  # An empty list without a filter introduces the payments of its class.
  # With a filter, it only says that nothing matches.
  def empty_state
    if filter.active?
      Ui::EmptyState::Component.new(icon: 'filter', title: t('.empty_filtered'))
    else
      Ui::EmptyState::Component.new(icon: 'hand-holding-dollar', title: t('.empty_title'), text: t(".empty.#{payment_class.model_name.param_key}"))
    end
  end
end
