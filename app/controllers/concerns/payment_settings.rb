# The settings page of the payments of the cars or of the heat pump (see
# Payment). The comparison counts some of them, so the page needs it. Its
# form opens in the modal on the desktop and on a page of its own on a phone
# (see FormPageResponse).
#
# The list loads more rows while it scrolls (see Ui::LazyRows). A filter
# narrows it (see FilteredList), and a new payment takes its category.
#
# The controller names the class of the payments and the filter, and closes
# the page without the comparison:
#
#   filters_with Heatpump::PaymentFilter
#   def payment_class = Heatpump::Payment
#   def comparison_required! = heatpump_settings_required!
module PaymentSettings
  extend ActiveSupport::Concern
  include Pagy::Method
  include FormPageResponse
  include FilteredList

  included do
    before_action :admin_required!
    before_action :comparison_required!
    before_action :load_payment, only: %i[edit update destroy]
    before_action :new_payment, only: %i[new create]

    helper_method :list_component, :title
  end

  def index
    @pagy, @payments = paginated_payments
    render(rows_component(@payments, @pagy), layout: false) if Ui::LazyRows::Component.request?(request, PaymentList::Rows::Component.frame_prefix(payment_class))
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
    path = url_for(controller: "/#{controller_path}", action: :index, only_path: true)
    pagy, payments = paginated_payments(request: { base_url: request.base_url, path:, params: filter.to_params })

    turbo_stream.update('list', list_component(payments, pagy))
  end

  def paginated_payments(**) = pagy(:countless, filtered_payments, **)

  def list_component(payments, pagy)
    PaymentList::Component.new(payments:, payment_class:, pagy:, total: filtered_payments.signed_sum, cars: payment_cars, filter:)
  end

  # A further page of the list. The date of the last payment of the page
  # before tells whether its first payment goes on with that year.
  def rows_component(payments, pagy)
    previous_date = filtered_payments.offset(pagy.offset - 1).pick(:date)
    PaymentList::Rows::Component.new(payments:, payment_class:, pagy:, car_column: payment_cars.many?, filter:, previous_date:, frame: true)
  end

  def title = t("settings.#{controller_name}.name")

  # The payments that the page shows
  def payment_scope = payment_class.all

  # The cars of the payments, none for the heat pump. With more than one,
  # the list has a column of the car.
  def payment_cars = []

  def filtered_payments = filter.apply(payment_scope.ordered)

  def permitted_params
    params.expect(payment_class.model_name.param_key => %i[category date amount note])
  end

  def load_payment
    @payment = payment_scope.find(params.expect(:id))
  end

  # A new payment takes the category of the filter, and the attributes that
  # the controller gives (see #new_payment_attributes)
  def new_payment
    @payment = payment_class.new(category: filter.category, date: Date.current, **new_payment_attributes)
    @payment.assign_attributes(permitted_params) if params[payment_class.model_name.param_key]
  end

  def new_payment_attributes = {}
end
