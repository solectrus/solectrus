describe PowerPeak do
  subject(:power_peak) { described_class.new(sensors:) }

  describe '#call' do
    subject { power_peak.call(start:) }

    let(:start) { 30.days.ago.beginning_of_day }

    context 'when no sensors are provided' do
      let(:sensors) { [] }

      it { is_expected.to be_nil }
    end

    context 'when multiple sensors are provided' do
      let(:sensors) { %i[inverter_power house_power] }

      context 'when no summaries exist' do
        it { is_expected.to be_nil }
      end

      context 'when summaries are present' do
        before do
          create_summary(
            date: start,
            values: [[:inverter_power, :max, 1000], [:house_power, :max, 2000]],
          )

          create_summary(
            date: start + 1.day,
            values: [[:inverter_power, :max, 1500], [:house_power, :max, 2500]],
          )
        end

        it 'returns the maximum value if all sensors' do
          is_expected.to eq(inverter_power: 1500, house_power: 2500)
        end
      end
    end

    context 'when one sensor is provided' do
      let(:sensors) { %i[inverter_power] }

      context 'when no summaries exist' do
        it { is_expected.to be_nil }
      end

      context 'when summaries are present' do
        before do
          create_summary(date: start, values: [[:inverter_power, :max, 1000]])

          create_summary(
            date: start + 1.day,
            values: [[:inverter_power, :max, 1500]],
          )
        end

        it 'returns the maximum value for this sensor' do
          is_expected.to eq(inverter_power: 1500)
        end
      end
    end
  end
end
