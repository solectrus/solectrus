describe Queries::InfluxSum do
  let(:query_influx_sum) { described_class.new(timeframe) }
  let(:timeframe) { Timeframe.new(date.iso8601) }
  let(:date) { Date.new(2024, 10, 1) }

  describe '#initialize' do
    it 'preserves timeframe' do
      expect(query_influx_sum.timeframe).to eq(timeframe)
    end

    context 'without data' do
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
        battery_charging_power_grid
        custom_power_01_grid
        custom_power_02_grid
      ].each do |sensor|
        it "has method '#{sensor}' returning nil" do
          expect(query_influx_sum).to respond_to(sensor)

          expect(query_influx_sum.public_send(sensor)).to be_nil
        end
      end
    end

    context 'with data' do
      before do
        influx_batch do
          # Fill one hour (12:00 - 13:00) with 10 kW power
          13.times do |i|
            time = date.middle_of_day + (5.minutes * i)

            add_influx_point name: measurement_inverter_power,
                             fields: {
                               field_inverter_power => 10_000,
                             },
                             time:
          end
        end
      end

      it 'sums up the power values' do
        expect(query_influx_sum.inverter_power).to eq(10_000) # 10 kWh
      end
    end
  end
end
