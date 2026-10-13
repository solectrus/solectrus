# The PV share of a charge as a small bar of PV and grid, with the percent.
# percent_class adds to the class of the percent, for example to hide it on a
# phone.
class ChargingSession::PvShareBar::Component < ViewComponent::Base
  def initialize(percent:, percent_class: nil)
    super()
    @percent = percent.clamp(0, 100)
    @percent_class = percent_class
  end

  attr_reader :percent, :percent_class

  def grid_percent
    100 - percent
  end

  # The list has no header, so a screen reader hears what the bar shows
  def label
    t('splitter.pv_percent', percent:)
  end
end
