describe Sensor::HomePage do
  # The order is the business of the menu, see
  # spec/components/chart_dropdown_logic_spec.rb.
  describe '.sensor_names' do
    it 'collects the sensors that name the page' do
      expect(described_class.sensor_names(:heatpump)).to contain_exactly(
        :heatpump_power,
        :heatpump_costs,
        :heatpump_cop,
        :heatpump_cop_scatter,
        :heatpump_heating_power,
        :heatpump_tank_temp,
        :outdoor_temp,
      )
    end

    it 'gives the house its two sensors and the custom consumers' do
      names = described_class.sensor_names(:house)
      customs = Sensor::Config.house_power_included_custom_sensors.map(&:name)

      expect(names).to contain_exactly(:house_power, *customs, :house_power_without_custom)
    end

    it 'follows a sensor that names two pages to both' do
      expect(described_class.sensor_names(:balance)).to include(:house_power)
      expect(described_class.sensor_names(:house)).to include(:house_power)
    end

    it 'skips a sensor without a chart' do
      expect(described_class.sensor_names(:balance)).not_to include(
        :inverter_power_forecast,
      )
    end

    it 'raises for an unknown page' do
      expect { described_class.sensor_names(:nope) }.to raise_error(
        ArgumentError,
      )
    end
  end

  describe '.page_for' do
    # The invariant that keeps links working: a link built for a sensor must
    # land on a page that renders it. Otherwise the controller sends the user
    # to the page default, and the click goes nowhere. Every name a menu can
    # offer has to pass, the halves of a combined chart included.
    it 'returns a page that accepts the sensor' do
      names =
        described_class.all.flat_map do |key|
          described_class
            .sensor_names(key)
            .flat_map { Sensor::Registry[it].chart_entry_names }
        end
      expect(names).not_to be_empty

      misrouted =
        names.reject do |name|
          described_class.accepts?(described_class.page_for(name), name)
        end

      expect(misrouted).to be_empty
    end

    it 'sends a custom consumer to the house page' do
      sensor = Sensor::Config.house_power_included_custom_sensors.first
      expect(described_class.page_for(sensor.name)).to eq(:house)
    end

    it 'sends house_power_without_custom to the house page' do
      expect(described_class.page_for(:house_power_without_custom)).to eq(:house)
    end

    it 'sends heatpump_costs to the heatpump page' do
      expect(described_class.page_for(:heatpump_costs)).to eq(:heatpump)
    end

    it 'keeps the system totals on the power balance' do
      %i[house_power heatpump_power inverter_power].each do |sensor_name|
        expect(described_class.page_for(sensor_name)).to eq(:balance)
      end
    end

    it 'skips a page the settings switched off' do
      allow(Setting).to receive(:enable_heatpump).and_return(false)

      expect(described_class.page_for(:heatpump_cop)).to eq(:balance)
    end

    it 'falls back to the power balance for a sensor without a page' do
      expect(described_class.page_for(:inverter_power_forecast)).to eq(:balance)
    end
  end

  describe '.accepts?' do
    it 'accepts a sensor the page lists' do
      expect(described_class).to be_accepts(:balance, :house_power)
    end

    # The menu offers the two halves, but a link from outside can carry the
    # name of the combined chart itself.
    it 'accepts a combined chart and both of its halves' do
      expect(described_class.sensor_names(:balance)).to include(:grid_power)

      expect(described_class).to be_accepts(:balance, :grid_power)
      expect(described_class).to be_accepts(:balance, :grid_import_power)
      expect(described_class).to be_accepts(:balance, :grid_export_power)
    end

    it 'rejects a sensor of another page' do
      expect(described_class).not_to be_accepts(:balance, :heatpump_cop)
    end

    it 'rejects a name no sensor claims' do
      expect(described_class).not_to be_accepts(:balance, :nonsense)
      expect(described_class).not_to be_accepts(
        :balance,
        :inverter_power_forecast,
      )
    end

    # The settings can switch off every page a sensor names. The power balance
    # takes the sensor over then, so a link from a Top10 row or a heatmap tile
    # still renders the chart instead of bouncing to the page default.
    it 'takes over a sensor whose only page is switched off' do
      allow(Setting).to receive(:enable_heatpump).and_return(false)

      expect(described_class.page_for(:heatpump_cop)).to eq(:balance)
      expect(described_class).to be_accepts(:balance, :heatpump_cop)
    end
  end
end
