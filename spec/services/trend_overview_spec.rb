describe TrendOverview do
  before do
    travel_to Date.new(2026, 3, 1)
    stub_feature(:trends)
  end

  describe '.available?' do
    def available?(sensor_name, page: :balance)
      described_class.available?(page:, sensor: Sensor::Registry[sensor_name], timeframe: Timeframe.new('2026-01'))
    end

    it 'is available for a sensor of the page' do
      expect(available?(:grid_power)).to be(true)
      expect(available?(:heatpump_power, page: 'heatpump')).to be(true)
    end

    it 'is available for a part of a net sensor, which has a row' do
      expect(available?(:grid_import_power)).to be(true)
    end

    it 'is not available for a sensor of another page' do
      expect(available?(:heatpump_cop)).to be(false)
    end

    it 'is not available without the permission' do
      stub_feature

      expect(available?(:grid_power)).to be(false)
    end
  end

  describe '.page_period?' do
    def available?(page: :balance, timeframe: Timeframe.new('2026-01'))
      described_class.page_period?(page:, timeframe:)
    end

    it 'is available for a month and a year of a home page' do
      expect(available?).to be(true)
      expect(available?(page: 'heatpump', timeframe: Timeframe.new('2025'))).to be(true)
      expect(available?(page: :cars)).to be(true)
    end

    it 'is available for the whole time' do
      expect(available?(timeframe: Timeframe.all)).to be(true)
      expect(available?(page: :cars, timeframe: Timeframe.all)).to be(true)
    end

    it 'is not available for a page beside the home pages' do
      expect(available?(page: :forecast)).to be(false)
    end

    it 'is not available for a week' do
      expect(available?(timeframe: Timeframe.new('2026-W02'))).to be(false)
    end

    it 'is not available on the first day of a period' do
      expect(available?(timeframe: Timeframe.new('2026-03'))).to be(false)
    end

    # A visitor of the car page sees the days up to two days ago
    it 'needs two days that the period shows' do
      travel_to Date.new(2026, 3, 4)

      expect(available?(timeframe: Timeframe.new('2026-03', max_date: Date.new(2026, 3, 1)))).to be(false)
      expect(available?(timeframe: Timeframe.new('2026-03', max_date: Date.new(2026, 3, 2)))).to be(true)
    end
  end

  describe '.label' do
    it 'calls the heat pump its electricity on its own page' do
      sensor = Sensor::Registry[:heatpump_power]

      expect(described_class.label(sensor, page: 'heatpump')).to eq('Power consumption')
      expect(described_class.label(sensor, page: :balance)).to eq(sensor.display_name)
    end
  end

  describe '.bases' do
    it 'compares a month with the year and the month before' do
      expect(described_class.bases(Timeframe.new('2026-01'))).to eq(%i[previous_year previous_period])
    end

    it 'compares a year with the year before only' do
      expect(described_class.bases(Timeframe.new('2025'))).to eq(%i[previous_year])
    end
  end
end
