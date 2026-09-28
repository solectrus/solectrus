describe Sensor::Query::FirstSeen do
  subject(:first_seen) do
    described_class.new(%i[battery_soc house_power]).call
  end

  describe '#call' do
    context 'without any data' do
      it { is_expected.to eq({}) }
    end

    context 'with data far in the past' do
      let(:seen) { 5.months.ago }

      before do
        influx_batch do
          [seen, 3.months.ago].each do |time|
            add_influx_point(
              name: Sensor::Config.measurement(:battery_soc),
              fields: {
                Sensor::Config.field(:battery_soc) => 42.0,
              },
              time:,
            )
          end
        end
      end

      it 'reports the oldest data point of that sensor' do
        expect(first_seen[:battery_soc]).to be_within(1.second).of(seen)
      end

      it 'omits a sensor that never delivered' do
        expect(first_seen).not_to have_key(:house_power)
      end
    end
  end
end
