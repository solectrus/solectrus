describe Sensor::Query::LastSeen do
  subject(:last_seen) { described_class.new(%i[battery_soc house_power]).call }

  describe '#call' do
    context 'without any data' do
      it { is_expected.to eq({}) }
    end

    context 'with data far outside the live window' do
      let(:seen) { 3.months.ago }

      before do
        influx_batch do
          [5.months.ago, seen].each do |time|
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

      it 'reports the newest data point of that sensor' do
        expect(last_seen[:battery_soc]).to be_within(1.second).of(seen)
      end

      it 'omits a sensor that never delivered' do
        expect(last_seen).not_to have_key(:house_power)
      end
    end
  end
end
