# The rows of one page of the payments (see Car::PaymentList::Component)
class Car::PaymentList::Rows::Component < ViewComponent::Base
  # Each page of the list loads into a Turbo frame of its own (see Ui::LazyRows)
  FRAME_PREFIX = 'car_payments_page_'.freeze
  public_constant :FRAME_PREFIX

  def initialize(payments:, pagy:, car_column:, filter:, frame: false)
    super()
    @payments = payments
    @pagy = pagy
    @car_column = car_column
    @filter = filter
    @frame = frame
  end

  def call
    render Ui::LazyRows::Component.new(prefix: FRAME_PREFIX, pagy: @pagy, frame: @frame) do
      safe_join(@payments.map { render Car::PaymentList::Row::Component.new(payment: it, filter: @filter, car_column: @car_column) })
    end
  end
end
