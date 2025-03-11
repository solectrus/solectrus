# @label EssentialsTile
class EssentialsTileComponentPreview < ViewComponent::Preview
  # @!group Misc
  def now
    timeframe Timeframe.now
    render EssentialsTile::Component.new calculator:,
                                         sensor: 'inverter_power',
                                         timeframe:
  end

  def day
    timeframe Timeframe.day
    render EssentialsTile::Component.new calculator:,
                                         sensor: 'inverter_power',
                                         timeframe:
  end

  def month
    timeframe Timeframe.month
    render EssentialsTile::Component.new calculator:,
                                         sensor: 'inverter_power',
                                         timeframe:
  end

  def year
    timeframe Timeframe.year
    render EssentialsTile::Component.new calculator:,
                                         sensor: 'inverter_power',
                                         timeframe:
  end

  def savings
    timeframe Timeframe.year
    render EssentialsTile::Component.new calculator:,
                                         sensor: 'savings',
                                         timeframe:
  end
  # @!endgroup

  private

  def timeframe(value = nil)
    @timeframe = value if value
    @timeframe
  end

  def calculator
    @calculator ||=
      if @timeframe.now?
        Calculator::Now.new(%i[inverter_power])
      else
        Calculator::Range.new(@timeframe)
      end
  end
end
