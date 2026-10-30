# @label CarPaymentCategoryPill
# @logical_path data_display
class CarPaymentCategoryPillComponentPreview < ViewComponent::Preview
  # Every category side by side: the expenses red, the incomes green
  def all
    render_with_template(locals: { categories: Car::Payment.categories.keys })
  end
end
