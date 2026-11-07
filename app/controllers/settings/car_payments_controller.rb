# The payments of the cars: everything a car costs or earns, by category
# (see Car::Payment and PaymentSettings). The comparison with a combustion
# car counts some of them. The page is a tab beside the cars.
#
# A filter of a car, of categories and of a range of dates narrows the list
# (see Car::PaymentFilter). The links of the rows and of the comparison set
# it, and a new payment takes its car and its category.
class Settings::CarPaymentsController < ApplicationController
  include SettingsNavigation
  include PaymentSettings

  filters_with Car::PaymentFilter

  private

  def payment_class = Car::Payment

  # Only the comparison counts the payments, so they need its fuel prices
  # (see Car::Comparison.available?)
  def comparison_required! = (redirect_to(settings_cars_path) unless Car::Comparison.available?)

  # One page of the payments. Their cars come from the cars of the request,
  # so the page needs no query of its own for them.
  def paginated_payments(**)
    super.tap do |_, payments|
      ActiveRecord::Associations::Preloader.new(records: payments, associations: :car, available_records: cars).call
    end
  end

  def filter_context = { cars: }

  def payment_scope = Car::Payment.where(car: cars)

  def payment_cars = cars

  def cars = (@cars ||= Car.configured)

  def permitted_params
    params.expect(car_payment: %i[car_id category date amount note])
  end

  # A new payment takes the car of the filter, so the next rate of a lease
  # needs the date and the amount alone. Without a car in the filter, it
  # belongs to the newest car, and the form offers the others.
  def new_payment_attributes = { car: filter.car || cars.max_by { [it.active_from, it.id] } }
end
