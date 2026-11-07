# The filter of the list of the payments of the heat pump (see
# Heatpump::Payment and ListFilter): some categories and a range of dates.
# The chevrons of the rows set it.
Heatpump::PaymentFilter = Data.define(:categories, :from, :to) do
  include ListFilter

  def self.category_keys = Heatpump::Payment.categories.keys
end
