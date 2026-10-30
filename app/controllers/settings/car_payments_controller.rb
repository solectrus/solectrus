# The payments of the cars: everything a car costs or earns, by category
# (see Car::Payment). The comparison with a combustion car counts some of
# them. The page is a tab beside the cars, and its form opens in the modal on
# the desktop and on a page of its own on a phone (see FormPageResponse).
#
# The list loads more rows while it scrolls (see Ui::LazyRows). A filter of
# a car, of categories and of a range of dates narrows it (see
# Car::PaymentFilter and FilteredList). The links of the rows and of the
# comparison set it, and a new payment takes its car and its category.
class Settings::CarPaymentsController < ApplicationController
  include SettingsNavigation
  include Pagy::Method
  include FormPageResponse
  include FilteredList

  filters_with Car::PaymentFilter

  before_action :admin_required!
  # Only the comparison counts the payments, so they need its fuel prices
  # (see Car::Comparison.available?)
  before_action { redirect_to(settings_cars_path) unless Car::Comparison.available? }
  before_action :load_payment, only: %i[edit update destroy]
  before_action :new_payment, only: %i[new create]

  def index
    @pagy, @payments = paginated_payments
    render(rows_component(@payments, @pagy), layout: false) if Ui::LazyRows::Component.request?(request, Car::PaymentList::Rows::Component::FRAME_PREFIX)
  end

  def new
  end

  def edit
  end

  def create = respond_to_save(@payment, @payment.save)

  def update = respond_to_save(@payment, @payment.update(permitted_params))

  def destroy
    @payment.destroy!
    respond_with_list(notice: t('crud.deleted'))
  end

  private

  # Refresh the list straight from the mutating request, with the filter of
  # the list that opened the form. The list starts over at page 1, and its
  # follow-up pages load with the filter in their query.
  def list_stream
    pagy, payments =
      paginated_payments(request: { base_url: request.base_url, path: settings_car_payments_path, params: filter.to_params })

    turbo_stream.update('list', list_component(payments, pagy))
  end

  # One page of the payments. Their cars come from the cars of the request,
  # so the page needs no query of its own for them.
  def paginated_payments(**)
    pagy, payments = pagy(:countless, filtered_payments, **)
    ActiveRecord::Associations::Preloader.new(records: payments, associations: :car, available_records: cars).call

    [pagy, payments]
  end

  def list_component(payments, pagy)
    Car::PaymentList::Component.new(payments:, pagy:, total: filtered_payments.signed_sum, cars:, filter:)
  end

  helper_method :list_component

  # A further page of the list. The date of the last payment of the page
  # before tells whether its first payment goes on with that year.
  def rows_component(payments, pagy)
    previous_date = filtered_payments.offset(pagy.offset - 1).pick(:date)
    Car::PaymentList::Rows::Component.new(payments:, pagy:, car_column: cars.many?, filter:, previous_date:, frame: true)
  end

  helper_method def title
    t('settings.car_payments.name')
  end

  def filter_context = { cars: }

  def filtered_payments = filter.apply(Car::Payment.where(car: cars).ordered)

  def cars = (@cars ||= Car.configured)

  def permitted_params
    params.expect(car_payment: %i[car_id category date amount note])
  end

  def load_payment
    @payment = Car::Payment.where(car: cars).find(params.expect(:id))
  end

  # A new payment takes the car and the category of the filter, so the next
  # rate of a lease needs the date and the amount alone. Without a car in
  # the filter, it belongs to the newest car, and the form offers the others.
  def new_payment
    car = filter.car || cars.max_by { [it.active_from, it.id] }
    @payment = Car::Payment.new(car:, category: filter.category, date: Date.current)
    @payment.assign_attributes(permitted_params) if params[:car_payment]
  end
end
