# Read-only notice above the cash-flow list, shown only when the list is
# filtered - either through a drill-down link from the amortization table or the
# per-row category chevrons in the list itself. There is deliberately no UI to
# compose a filter from scratch (date pickers proved unusable on mobile); the
# single action offered here is to clear it and return to the full list. Rendered
# outside the 'list' Turbo frame so a broadcast refresh does not drop the filter.
# The effective filter values are owned by the controller (validated there) and
# read back through the exposed helper methods.
class CashFlowFilter::Component < ViewComponent::Base
  delegate :filter_categories,
           :filter_from,
           :filter_to,
           :filter_active?,
           to: :helpers

  # One label per selected category, in canonical enum order.
  def category_labels
    filter_categories.map { |key| CashFlow.human_enum_name(:category, key) }
  end

  # The active date bounds as one readable range, or nil when neither is set.
  def date_range
    return if filter_from.nil? && filter_to.nil?

    if filter_from && filter_to
      "#{l(filter_from)} – #{l(filter_to)}"
    elsif filter_from
      "#{t('settings.cash_flows.from')} #{l(filter_from)}"
    else
      "#{t('settings.cash_flows.to')} #{l(filter_to)}"
    end
  end
end
