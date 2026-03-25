describe HouseBreakdown::TooltipComponent, type: :component do
  subject(:component) do
    described_class.new(sensor:, data:, timeframe:)
  end

  before { stub_feature(:power_splitter, :custom_consumer) }

  let(:sensor) { Sensor::Registry[:custom_power_01] }
  let(:updated_at) { 3.minutes.ago }

  let(:data) do
    HouseBalance.new(
      Sensor::Data::Single.new(
        raw_data,
        timeframe:,
        time: updated_at,
      ),
    )
  end

  let(:raw_data) do
    {
      house_power: 5000,
      custom_power_01: 1200,
      custom_power_01_grid: 600,
      custom_power_total: 1200,
      custom_costs_01: 0.50,
      custom_costs_01_grid: 0.30,
      custom_costs_01_pv: 0.20,
      grid_import_power: 100,
      grid_export_power: 200,
      inverter_power: 8000,
      battery_charging_power: 100,
      battery_discharging_power: 50,
      wallbox_power: 500,
      heatpump_power: 300,
    }
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

    it 'does not render costs' do
      html = render_inline(component).to_html

      expect(html).not_to include('splitted-costs')
    end
  end
end
