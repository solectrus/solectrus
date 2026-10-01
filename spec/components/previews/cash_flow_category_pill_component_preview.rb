# @label CashFlowCategoryPill
# @logical_path data_display
class CashFlowCategoryPillComponentPreview < ViewComponent::Preview
  # Every category side by side, so the color families can be compared:
  # investment (indigo), inflows (green), running costs (red/warm), other.
  def all
    render_with_template(locals: { categories: CashFlow.categories.keys })
  end
end
