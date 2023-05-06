# @label Balance Component
class BalanceComponentPreview < ViewComponent::Preview
  def left
    render Balance::Component.new side: :left,
                                  timeframe:,
                                  calculator: do |balance|
      balance.with_segment :grid_power_plus
      balance.with_segment :inverter_power
      balance.with_segment :bat_power_minus
    end
  end

  def right
    render Balance::Component.new side: :right,
                                  timeframe:,
                                  calculator: do |balance|
      balance.with_segment :wallbox_charge_power
      balance.with_segment :house_power
      balance.with_segment :grid_power_minus
      balance.with_segment :bat_power_plus
    end
  end

  private

  def calculator
    Calculator::Range.new(timeframe)
  end

  def timeframe
    Timeframe.new Date.current.strftime('%Y-%m')
  end
end
