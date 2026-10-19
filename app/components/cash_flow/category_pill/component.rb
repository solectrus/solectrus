# The category of a cash flow as a Ui::Badge
class CashFlow::CategoryPill::Component < ViewComponent::Base
  # Colour by economic effect so a pill's hue tells what it does: the investment
  # stands on its own (indigo); the inflows subsidy/refund/compensation/
  # manual_savings share a green family (money coming in); the running costs
  # operating_cost/repair share a red/warm family; other stays a neutral amber.
  # Within a family the categories use distinct but related hues at the same
  # brightness, not lightness steps.
  COLORS = {
    'investment' => :indigo,
    'subsidy' => :lime,
    'refund' => :green,
    'compensation' => :teal,
    'manual_savings' => :emerald,
    'operating_cost' => :red,
    'repair' => :orange,
    'other' => :amber,
  }.freeze
  private_constant :COLORS

  # `remove_path:` gives the pill a small x, see Ui::Badge
  def initialize(category:, remove_path: nil)
    super()
    @category = category
    @remove_path = remove_path
  end

  def call
    render Ui::Badge::Component.new(color: COLORS[@category], remove_path: @remove_path).with_content(CashFlow.human_enum_name(:category, @category))
  end
end
