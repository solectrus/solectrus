describe PowerPeak do
  subject(:power_peak) { described_class.new(sensors:) }

  describe '#call' do
    subject { power_peak.call(start:) }

    let(:start) { 30.days.ago.beginning_of_day }

    context 'when no sensors are provided' do
      let(:sensors) { [] }

      it { is_expected.to be_nil }
    end

    context 'when sensors are provided' do
      let(:sensors) { %i[inverter_power house_power] }

      context 'when no summaries exist' do
        it { is_expected.to be_nil }
      end

      context 'when summaries are present' do
        before do
          Summary.create!(
            date: start,
            max_inverter_power: 1000,
            max_house_power: 2000,
          )

          Summary.create!(
            date: start + 1.day,
            max_inverter_power: 1500,
            max_house_power: 2500,
          )
        end

        it 'returns the maximum value for each sensor' do
          is_expected.to eq(
            max_max_inverter_power: 1500,
            max_max_house_power: 2500,
          )
        end
      end
    end
  end
end
