# @label SocBadge
# @logical_path data_display
# @display max_width 6.5rem
class SocBadgeComponentPreview < ViewComponent::Preview
  # Color thresholds are the same for both batteries:
  # 0-5% negative, 6-20% warning, 21-100% positive

  # @!group Overview
  def critical
    soc_badge(battery_soc: 3, car_soc: 5)
  end

  def low
    soc_badge(battery_soc: 6, car_soc: 20)
  end

  def good
    soc_badge(battery_soc: 21, car_soc: 100)
  end

  def mixed
    soc_badge(battery_soc: 75, car_soc: 12)
  end

  def car_connected
    soc_badge(connected: true)
  end

  def car_disconnected
    soc_badge(connected: false)
  end

  def car_connection_unknown
    soc_badge(connected: nil)
  end
  # @!endgroup

  private

  def soc_badge(battery_soc: 75, car_soc: 80, connected: true)
    render SocBadge::Component.new(
             battery_soc: battery_soc.to_f,
             car: Car.new(id: 1, short_name: '1'),
             car_soc: car_soc.to_f,
             car_connected: connected,
             time: Time.current,
             timeframe: Timeframe.now,
           )
  end
end
