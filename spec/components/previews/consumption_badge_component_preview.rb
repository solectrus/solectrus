# @label ConsumptionBadge
# @logical_path data_display
# @display max_width 10rem
class ConsumptionBadgeComponentPreview < ViewComponent::Preview
  # The text box needs a heat pump or a wallbox, otherwise the radial badges
  # render instead (see RadialBadge).
  # Autarky: 0-33% negative, 34-66% warning, 67-100% positive

  # @!group Autarky
  def autarky_negative
    consumption_badge(autarky: 33)
  end

  def autarky_warning
    consumption_badge(autarky: 62)
  end

  def autarky_positive
    consumption_badge(autarky: 85)
  end
  # @!endgroup

  private

  def consumption_badge(autarky:)
    render ConsumptionBadge::Component.new(
             data: data(autarky:),
             timeframe: Timeframe.new(Date.current.strftime('%Y-%m')),
           )
  end

  def data(autarky:)
    PowerBalance.new(
      Sensor::Data::Single.new(
        {
          %i[inverter_power sum] => 15_000.0,
          %i[house_power sum] => 8000.0,
          %i[grid_import_power sum] => 2000.0,
          %i[grid_export_power sum] => 5000.0,
          %i[battery_charging_power sum] => 3000.0,
          %i[battery_discharging_power sum] => 2500.0,
          %i[wallbox_power sum] => 4000.0,
          %i[heatpump_power sum] => 1500.0,
          %i[self_consumption sum] => 10_000.0,
          %i[autarky avg] => autarky.to_f,
          %i[grid_quote avg] => 100.0 - autarky,
          %i[self_consumption_quote avg] => 26.0,
          %i[total_consumption sum] => 62_500.0,
        },
        timeframe: Timeframe.new(Date.current.strftime('%Y-%m')),
      ),
    )
  end
end
