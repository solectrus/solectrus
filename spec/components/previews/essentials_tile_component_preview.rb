# @label EssentialsTile
class EssentialsTileComponentPreview < ViewComponent::Preview
  # @!group Misc
  def now
    timeframe Timeframe.now
    render EssentialsTile::Component.new data:,
                                         sensor: Sensor::Registry[:inverter_power],
                                         timeframe:
  end

  def day
    timeframe Timeframe.day
    render EssentialsTile::Component.new data:,
                                         sensor: Sensor::Registry[:inverter_power],
                                         timeframe:
  end

  def month
    timeframe Timeframe.month
    render EssentialsTile::Component.new data:,
                                         sensor: Sensor::Registry[:inverter_power],
                                         timeframe:
  end

  def year
    timeframe Timeframe.year
    render EssentialsTile::Component.new data:,
                                         sensor: Sensor::Registry[:inverter_power],
                                         timeframe:
  end

  def savings
    timeframe Timeframe.year
    render EssentialsTile::Component.new data:,
                                         sensor: Sensor::Registry[:savings],
                                         timeframe:
  end
  # @!endgroup

  private

  def timeframe(value = nil)
    @timeframe = value if value
    @timeframe
  end

  def data
    @data ||=
      PowerBalance.new(
        Sensor::Data::Single.new(
          if @timeframe.now?
            {
              inverter_power: 2500.0,
              house_power: 1200.0,
              grid_import_power: 0.0,
              grid_export_power: 200.0,
              battery_soc: 75.0,
              savings: 0.0,
            }
          else
            {
              %i[inverter_power sum] => 15_000.0,
              %i[house_power sum] => 8000.0,
              %i[grid_import_power sum] => 2000.0,
              %i[grid_export_power sum] => 5000.0,
              %i[savings sum] => 125.50,
            }
          end,
          timeframe: @timeframe,
        ),
      )
  end
end
