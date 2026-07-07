# Interactive filter above the cash-flow list: narrow it by category and/or date
# range. Auto-submits on change (GET) and is the landing spot when drilling down
# from the amortization table into the flows behind a cell. Rendered outside the
# 'list' Turbo frame so a broadcast refresh does not drop the current filter.
# The effective filter values are owned by the controller (validated there) and
# read back through the exposed helper methods.
class CashFlowFilter::Component < ViewComponent::Base
  delegate :filter_categories,
           :filter_from,
           :filter_to,
           :filter_active?,
           to: :helpers

  # [label, value] pairs for the category checkboxes, in canonical enum order.
  def category_options
    CashFlow.categories.keys.map do |key|
      [CashFlow.human_enum_name(:category, key), key]
    end
  end

  # Summary shown on the closed dropdown, mirroring the Stimulus controller so
  # the server-rendered state (e.g. after a drill-down) already reads correctly.
  def summary_label
    case filter_categories.size
    when 0 then t('settings.cash_flows.all_categories')
    when 1 then CashFlow.human_enum_name(:category, filter_categories.first)
    else t('settings.cash_flows.categories_selected', count: filter_categories.size)
    end
  end

  # The "%{count}" template the Stimulus controller fills in for two or more
  # selections. Passing the placeholder as the count keeps it uninterpolated
  # (and picks the plural :other form).
  def count_label_template
    # rubocop:disable Style/FormatStringToken -- placeholder left uninterpolated for the Stimulus controller
    t('settings.cash_flows.categories_selected', count: '%{count}')
    # rubocop:enable Style/FormatStringToken
  end
end
