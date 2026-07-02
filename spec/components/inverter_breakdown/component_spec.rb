describe InverterBreakdown::Component, type: :component do
  subject(:component) do
    described_class.new(data:, timeframe:, sensor_name: :inverter_power)
  end

  let(:timeframe) { Timeframe.day }
  let(:updated_at) { 3.minutes.ago }

  let(:data) do
    InverterBalance.new(
      Sensor::Data::Single.new(
        {
          inverter_power: 5000,
          inverter_power_1: 3000,
          inverter_power_2: 1800,
          inverter_power_total: 4800,
          inverter_power_difference: 200,
        },
        timeframe:,
        times: { inverter_power: updated_at },
      ),
    )
  end

  describe '#breakdown?' do
    it 'is true when custom inverter sensors are configured' do
      expect(component.breakdown?).to be(true)
    end
  end

  describe '#table_rows' do
    it 'includes the individual inverter sensors' do
      sensors = component.table_rows.map { |r| r[:sensor].name }

      expect(sensors).to include(:inverter_power_1, :inverter_power_2)
    end

    it 'sorts by percent descending' do
      percents = component.table_rows.pluck(:percent)

      expect(percents).to eq(percents.sort_by(&:-@))
    end

    it 'excludes sensors with zero value and zero percent' do
      zero_rows = component.table_rows.select { |r| r[:percent].zero? }

      expect(zero_rows).to be_empty
    end
  end

  describe '#other_sensor' do
    it 'returns the inverter_power_difference sensor' do
      expect(component.other_sensor.name).to eq(:inverter_power_difference)
    end
  end

  describe '#other_percent' do
    it 'calculates percent relative to inverter_power' do
      expect(component.other_percent).to eq(200.fdiv(5000) * 100.0)
    end
  end

  describe '#show_other?' do
    it 'is true when there is an unassigned difference' do
      expect(component.show_other?).to be(true)
    end

    context 'without a difference' do
      let(:data) do
        InverterBalance.new(
          Sensor::Data::Single.new(
            {
              inverter_power: 4800,
              inverter_power_1: 3000,
              inverter_power_2: 1800,
              inverter_power_total: 4800,
              inverter_power_difference: 0,
            },
            timeframe:,
            times: { inverter_power: updated_at },
          ),
        )
      end

      it 'is false' do
        expect(component.show_other?).to be(false)
      end
    end
  end

  describe '#no_production?' do
    it 'is false when producing' do
      expect(component.no_production?).to be(false)
    end

    context 'without production' do
      let(:data) do
        InverterBalance.new(
          Sensor::Data::Single.new(
            { inverter_power: 0 },
            timeframe:,
            times: { inverter_power: updated_at },
          ),
        )
      end

      it 'is true' do
        expect(component.no_production?).to be(true)
      end
    end
  end

  describe '#common_scaling' do
    # Thresholds: < 1_000 -> :off, < 1_000_000 -> :kilo, >= 1_000_000 -> :mega
    it 'returns :kilo for kilowatt range values' do
      expect(component.common_scaling).to eq(:kilo)
    end
  end

  describe 'rendering' do
    it 'renders both the toggle and table rows' do
      render_inline(component)

      expect(page).to have_css('button[aria-label]')
      expect(page).to have_css('#table-row-inverter_power_1')
      expect(page).to have_css('#table-row-inverter_power_2')
    end
  end
end
