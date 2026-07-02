describe InverterBreakdown::Tooltip::Component, type: :component do
  subject(:component) do
    described_class.new(sensor:, data:, timeframe:)
  end

  let(:sensor) { Sensor::Registry[:inverter_power_1] }
  let(:updated_at) { 3.minutes.ago }

  let(:data) do
    InverterBalance.new(
      Sensor::Data::Single.new(
        {
          inverter_power: 5000,
          inverter_power_1: 3000,
          inverter_power_2: 1800,
          inverter_power_total: 4800,
        },
        timeframe:,
        times: { inverter_power: updated_at },
      ),
    )
  end

  context 'when timeframe is day' do
    let(:timeframe) { Timeframe.day }

    it 'renders sensor name and value' do
      render_inline(component)

      expect(page).to have_text(sensor.display_name)
    end
  end

  context 'when timeframe is now' do
    let(:timeframe) { Timeframe.now }

    it 'renders sensor name' do
      render_inline(component)

      expect(page).to have_text(sensor.display_name)
    end
  end
end
