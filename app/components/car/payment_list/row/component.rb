# A payment in the list (see Car::PaymentList::Component): a row of the grid
# on the desktop and a cell of a grouped list on a phone. On the desktop, a
# chevron beside the date, the car and the category narrows the list to the
# year, the car or the category of the row (see Car::PaymentFilter). It shows
# while the pointer rests on the row, and not for a value that the filter
# holds already.
class Car::PaymentList::Row::Component < ViewComponent::Base
  def initialize(payment:, filter:, car_column:)
    super()
    @payment = payment
    @filter = filter
    @car_column = car_column
  end

  attr_reader :payment, :filter

  def car_column? = @car_column

  # The form leads back to this list (see ListAddress)
  def edit_path = helpers.edit_settings_car_payment_path(payment, return_to: helpers.list_address)

  def category_name = Car::Payment.human_enum_name(:category, payment.category)

  def amount = number_to_currency(payment.signed_amount, precision: 2, unit: Currency.symbol)

  def amount_color = payment.signed_amount.negative? ? 'text-signal-negative' : 'text-signal-positive'
end
