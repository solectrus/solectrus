describe Queries::InfluxAggregation do
  let(:query) { described_class.new(timeframe) }
  let(:timeframe) { Timeframe.new(date.iso8601) }
  let(:date) { Date.new(2024, 10, 1) }

  describe '#initialize' do
    it 'preserves timeframe' do
      expect(query.timeframe).to eq(timeframe)
    end

    context 'without data' do
      %i[
        inverter_power
        house_power
        wallbox_power
        heatpump_power
        grid_import_power
        grid_export_power
        battery_discharging_power
        battery_charging_power
        battery_soc
        car_battery_soc
        case_temp
      ].each do |sensor|
        it "has methods min/max/mean for '#{sensor}' returning nil" do
          expect(query).to respond_to(:"min_#{sensor}")
          expect(query.public_send(:"min_#{sensor}")).to be_nil

          expect(query).to respond_to(:"max_#{sensor}")
          expect(query.public_send(:"max_#{sensor}")).to be_nil

          expect(query).to respond_to(:"mean_#{sensor}")
          expect(query.public_send(:"mean_#{sensor}")).to be_nil
        end
      end
    end

    context 'when data is present' do
      before do
        add_influx_point name: measurement_inverter_power,
                         fields: {
                           field_inverter_power => 10_000,
                         },
                         time: date.middle_of_day
      end

      it 'returns the maximum power values' do
        expect(query.max_inverter_power).to eq(10_000)
      end
    end

    context "when a sensor doesn't exist" do
      before do
        allow(SensorConfig.x).to receive(:exists?).and_return(true)
        allow(SensorConfig.x).to receive(:exists?).with(
          :car_battery_soc,
          check_policy: false,
        ).and_return(false)
      end

      it 'returns nil' do
        expect(query.min_car_battery_soc).to be_nil
        expect(query.max_car_battery_soc).to be_nil
        expect(query.mean_car_battery_soc).to be_nil
      end
    end
  end
end
