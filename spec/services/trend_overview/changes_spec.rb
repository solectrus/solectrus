describe TrendOverview::Changes do
  subject(:overview) { described_class.new(page:, timeframe:, base: :previous_year) }

  let(:page) { :balance }
  let(:timeframe) { Timeframe.new('2026-01') }

  before do
    travel_to Date.new(2026, 3, 1)
    stub_feature(:trends)

    create_summary(
      date: Date.new(2025, 1, 1),
      values: [
        [:inverter_power, :sum, 10_000],
        [:grid_import_power, :sum, 2_000],
        [:grid_export_power, :sum, 5_000],
        [:battery_charging_power, :sum, 1_000],
        [:battery_discharging_power, :sum, 1_000],
        [:house_power, :sum, 4_000],
        [:outdoor_temp, :avg, 3.0],
      ],
    )
    create_summary(
      date: Date.new(2026, 1, 1),
      values: [
        [:inverter_power, :sum, 10_020],
        [:grid_import_power, :sum, 3_200],
        [:grid_export_power, :sum, 4_000],
        [:battery_charging_power, :sum, 1_000],
        [:battery_discharging_power, :sum, 500],
        [:house_power, :sum, 3_600],
        [:outdoor_temp, :avg, 3.5],
      ],
    )
  end

  def row(name) = overview.rows.find { it.sensor.name == name }

  describe '#rows' do
    it 'shows the parts of a net sensor' do
      names = overview.rows.map { it.sensor.name }

      expect(names).to include(:grid_import_power, :grid_export_power, :battery_charging_power, :battery_discharging_power)
      expect(names).not_to include(:grid_power, :battery_power)
    end

    it 'leaves out a sensor of the page without a trend' do
      expect(overview.rows.map { it.sensor.name }).not_to include(:power_balance, :co2_reduction)
    end

    it 'compares a sum in percent' do
      expect(row(:grid_import_power)).to have_attributes(kind: :percent, change: be_within(0.01).of(60), rating: :worse)
      expect(row(:grid_export_power)).to have_attributes(change: be_within(0.01).of(-20), rating: :worse)
      expect(row(:house_power)).to have_attributes(change: be_within(0.01).of(-10), rating: :better)
    end

    it 'rates a change that rounds to zero as the same' do
      expect(row(:inverter_power).rating).to eq(:same)
    end

    it 'has no change without a value of the earlier period' do
      create_summary(date: Date.new(2026, 1, 2), values: [[:wallbox_power, :sum, 1_000]])

      expect(row(:wallbox_power).change).to be_nil
    end

    it 'has no change without a value of its own period' do
      [Date.new(2024, 12, 1), Date.new(2025, 1, 2)].each do |date|
        create_summary(date:, values: [[:wallbox_power, :sum, 1_000]])
      end

      expect(row(:wallbox_power)).to have_attributes(change: nil, rating: nil)
    end

    # Today has not ended, so a running month compares up to yesterday
    it 'compares the days of a running month up to yesterday' do
      travel_to Date.new(2026, 1, 15)
      create_summary(date: Date.new(2025, 1, 2), values: [[:inverter_power, :sum, 1_000]])
      create_summary(date: Date.new(2025, 1, 15), values: [[:inverter_power, :sum, 1_000]])
      create_summary(date: Date.new(2026, 1, 2), values: [[:inverter_power, :sum, 1_000]])
      create_summary(date: Date.new(2026, 1, 15), values: [[:inverter_power, :sum, 500]])

      expect(row(:inverter_power).rating).to eq(:same)
    end

    it 'has no row without a value in either period' do
      expect(row(:wallbox_power)).to be_nil
    end
  end

  describe '#groups' do
    it 'orders the groups' do
      expect(overview.groups.keys).to eq(overview.groups.keys.sort_by { described_class::GROUPS.index(it) })
      expect(overview.groups[:generation].map { it.sensor.name }).to eq([:inverter_power])
      expect(overview.groups[:grid_battery].map { it.sensor.name }).to include(:grid_import_power)
      expect(overview.groups[:finance].map { it.sensor.name }).to include(:savings)
      expect(overview.groups[:quotas].map { it.sensor.name }).to include(:autarky)
    end

    # Not the order in which the sensors load
    it 'keeps a fixed order within a group' do
      expect(overview.groups[:grid_battery].map { it.sensor.name }).to eq(
        %i[grid_import_power grid_export_power battery_charging_power battery_discharging_power],
      )
    end

    context 'with the heat pump page' do
      let(:page) { :heatpump }

      it 'shows the change of an average as its difference' do
        temp = row(:outdoor_temp)

        expect(overview.groups[:averages]).to include(temp)
        expect(temp).to have_attributes(kind: :difference, change: be_within(0.01).of(0.5), precision: 1)
      end

      it 'shows the difference from a base value of zero' do
        create_summary(date: Date.new(2025, 1, 1), values: [[:outdoor_temp, :avg, 0.0]])

        expect(row(:outdoor_temp).change).to be_within(0.01).of(3.5)
      end

      # The weather is neither better nor worse
      it 'rates the change of a neutral sensor neither way' do
        expect(row(:outdoor_temp).rating).to eq(:neutral)
      end
    end
  end

  describe '#base_timeframe' do
    it { expect(overview.base_timeframe.to_s).to eq('2025-01') }
  end

  describe '#link_params' do
    it 'keeps the earlier period, but not the default' do
      expect(overview.link_params).to eq(base: nil)
      expect(described_class.new(page:, timeframe:, base: :previous_period).link_params).to eq(base: :previous_period)
    end
  end
end
