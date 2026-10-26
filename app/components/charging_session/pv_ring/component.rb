# The PV share of a wallbox session as a small ring at the start of its row on
# a phone: the PV share in green and the grid share in red, with the percent in
# the ring. The desktop shows the share as a bar (see
# ChargingSession::PvShareBar::Component). Without the power splitter, the ring
# has the color of the wallbox and no percent.
class ChargingSession::PvRing::Component < ViewComponent::Base
  # `percent` is the PV share in whole percents, or nil without the power
  # splitter
  def initialize(percent:)
    super()
    @percent = percent
  end

  attr_reader :percent

  def ring_style
    if percent
      "background: #{ConicGradient.css([['var(--color-car-pv)', percent], ['var(--color-car-grid)', 100 - percent]])}"
    else
      'background: var(--color-car-wallbox)'
    end
  end
end
