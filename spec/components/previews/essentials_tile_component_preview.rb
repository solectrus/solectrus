# @label EssentialsTile
class EssentialsTileComponentPreview < ViewComponent::Preview
  # @!group Misc
  def now
    render EssentialsTile::Component.new field: 'inverter_power',
                                         timeframe: Timeframe.now
  end

  def day
    render EssentialsTile::Component.new field: 'inverter_power',
                                         timeframe: Timeframe.today
  end

  def month
    render EssentialsTile::Component.new field: 'inverter_power',
                                         timeframe: Timeframe.month
  end

  def year
    render EssentialsTile::Component.new field: 'inverter_power',
                                         timeframe: Timeframe.year
  end

  def savings
    render EssentialsTile::Component.new field: 'savings',
                                         timeframe: Timeframe.year
  end
  # @!endgroup
end
