# The category of a car payment as a pill, for the filter of the list of
# the payments (see PaymentCategoryPill::Component)
class Car::PaymentCategoryPill::Component < PaymentCategoryPill::Component
  def self.payment_class = Car::Payment
end
