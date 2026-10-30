# The filter of the list of the payments (see Car::Payment and ListFilter):
# a car, some categories and a range of dates. The chevrons of the rows and
# the links of the comparison with a combustion car set it. A car that is
# not configured stays out.
Car::PaymentFilter = Data.define(:car, :categories, :from, :to) do
  include ListFilter

  def self.category_keys = Car::Payment.categories.keys

  def self.from_params(params, cars:)
    car_id = params.to_h.with_indifferent_access[:car].to_s.presence&.to_i
    super(params).with(car: cars.find { it.id == car_id })
  end

  def active? = car.present? || super

  def apply(scope) = super(car ? scope.where(car:) : scope)

  def to_params = { car: car&.id }.compact.merge(super)

  # The filter with another car or without one
  def with_car(car) = with(car:)
  def without_car = with(car: nil)

  # The category of a new payment: the one of the filter, when it has a
  # single one
  def category = (categories.sole if categories.one?)
end
