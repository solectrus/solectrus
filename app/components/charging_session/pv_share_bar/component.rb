# The PV share of a charge as a small bar of PV and grid, with the percent
class ChargingSession::PvShareBar::Component < ViewComponent::Base
  def initialize(percent:)
    super()
    @percent = percent.clamp(0, 100)
  end

  attr_reader :percent

  def grid_percent
    100 - percent
  end

  # The list has no header, so a screen reader hears what the bar shows
  def label
    t('splitter.pv_percent', percent:)
  end
end
