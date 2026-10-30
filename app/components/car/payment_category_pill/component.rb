# The category of a car payment as a Ui::Badge. Its hue tells the direction,
# like the pills of the cash flows: an expense red, an income green.
class Car::PaymentCategoryPill::Component < ViewComponent::Base
  # `remove_path:` gives the pill a small x, see Ui::Badge
  def initialize(category:, remove_path: nil)
    super()
    @category = category
    @remove_path = remove_path
  end

  def call
    render Ui::Badge::Component.new(color: Car::Payment.income?(@category) ? :green : :red, remove_path: @remove_path).with_content(Car::Payment.human_enum_name(:category, @category))
  end
end
