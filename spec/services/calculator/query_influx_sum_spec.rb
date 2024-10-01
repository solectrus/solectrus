describe Calculator::QueryInfluxSum do
  let(:query_influx_sum) { described_class.new(timeframe) }

  describe '#initialize' do
    let(:timeframe) { Timeframe.day }

    it 'preserves timeframe' do
      expect(query_influx_sum.timeframe).to eq(timeframe)
    end

    %i[
      inverter_power
      inverter_power_forecast
      house_power
      wallbox_power
      heatpump_power
      grid_import_power
      grid_export_power
      battery_discharging_power
      battery_charging_power
      house_power_grid
      wallbox_power_grid
      heatpump_power_grid
    ].each do |sensor|
      it "has method '#{sensor}'" do
        expect(query_influx_sum.public_send(sensor)).to be_nil
      end
    end
  end
end
