# The sensors of a page come from the sensors themselves (`home_pages`), the
# menu only arranges them. These examples hold the arrangement: the order a
# page shows, and where the separator goes.
describe ChartDropdownLogic do
  def menu_items_of(klass)
    klass.new(sensor_name: :house_power, timeframe: nil).__send__(:menu_items)
  end

  describe HeatpumpChartDropdown::Component do
    subject(:items) { menu_items_of(described_class) }

    it 'keeps the order of the page and sets the scatter apart' do
      expect(items).to eq(
        %i[
          heatpump_power
          heatpump_costs
          heatpump_cop
          outdoor_temp
          heatpump_heating_power
          heatpump_tank_temp
          _
          heatpump_cop_scatter
        ],
      )
    end
  end

  describe HouseChartDropdown::Component do
    subject(:items) { menu_items_of(described_class) }

    it 'puts the custom consumers between the two house sensors' do
      expect(items.first).to eq(:house_power)
      expect(items.second).to eq(:_)
      expect(items[-2]).to eq(:_)
      expect(items.last).to eq(:house_power_without_custom)
    end

    it 'sorts the custom consumers by display name' do
      names = items[2..-3].map { Sensor::Registry[it].display_name.downcase }

      expect(names).to eq(names.sort)
    end
  end

  describe InverterChartDropdown::Component do
    subject(:items) { menu_items_of(described_class) }

    it 'sets the total apart from the single inverters' do
      expect(items).to eq(%i[inverter_power _ inverter_power_1 inverter_power_2])
    end
  end

  describe BalanceChartDropdown::Component do
    subject(:items) { menu_items_of(described_class) }

    it 'goes by display name and draws no line' do
      names = items.map { Sensor::Registry[it].display_name(:long).downcase }

      expect(items).not_to include(:_)
      expect(names).to eq(names.sort)
    end
  end
end
