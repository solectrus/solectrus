# The category of a payment (see Payment) as a Ui::Badge. Its hue tells the
# direction, like the pills of the cash flows: an expense red, an income
# green. Ui::FilterBar builds a pill from the category alone, so each class
# of payments has a pill of its own that names the class (see
# Car::PaymentCategoryPill and Heatpump::PaymentCategoryPill).
class PaymentCategoryPill::Component < ViewComponent::Base
  # `remove_path:` gives the pill a small x, see Ui::Badge
  def initialize(category:, payment_class: self.class.payment_class, remove_path: nil)
    super()
    @category = category
    @payment_class = payment_class
    @remove_path = remove_path
  end

  def call
    render Ui::Badge::Component.new(color: @payment_class.income?(@category) ? :green : :red, remove_path: @remove_path).with_content(@payment_class.human_enum_name(:category, @category))
  end
end
