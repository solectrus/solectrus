describe Calculator::QueryInfluxDiff do
  let(:query) { described_class.new(timeframe) }
  let(:timeframe) { Timeframe.new(date.iso8601) }
  let(:date) { Date.new(2024, 10, 1) }

  describe '#initialize' do
    it 'preserves timeframe' do
      expect(query.timeframe).to eq(timeframe)
    end

    context 'without data' do
      %i[car_mileage].each do |sensor|
        it "has diff method for '#{sensor}' returning nil" do
          expect(query).to respond_to(:"diff_#{sensor}")
          expect(query.public_send(:"diff_#{sensor}")).to be_nil
        end
      end
    end

    context 'when data is present' do
      before do
        # Three full days with 90 km difference
        influx_batch do
          add_influx_point name: measurement_car_mileage,
                           fields: {
                             field_car_mileage => 100.0,
                           },
                           time: (date - 1.day).beginning_of_day

          add_influx_point name: measurement_car_mileage,
                           fields: {
                             field_car_mileage => 190.0,
                           },
                           time: (date + 1.day).end_of_day
        end
      end

      it 'returns the correct diff value' do
        expect(query.diff_car_mileage).to eq(30)
      end
    end

    context "when a sensor doesn't exist" do
      before do
        allow(SensorConfig.x).to receive(:exists?).and_return(true)
        allow(SensorConfig.x).to receive(:exists?).with(
          :car_mileage,
          check_policy: false,
        ).and_return(false)
      end

      it 'returns nil' do
        expect(query.diff_car_mileage).to be_nil
      end
    end
  end
end
