# The category of a payment of the heat pump as a pill, for the filter of
# the list of the payments (see PaymentCategoryPill::Component)
class Heatpump::PaymentCategoryPill::Component < PaymentCategoryPill::Component
  def self.payment_class = Heatpump::Payment
end
