class FakeData < ChartData::Base
  def data
    if timeframe.future?
      {
        labels: [],
        datasets: [{ label: 'Foo', data: [] }, { label: 'Bar', data: [] }],
      }
    else
      {
        labels: [5.minutes.ago, 4.minutes.ago, 3.minutes.ago],
        datasets: [
          { label: 'Foo', data: [1, 2, 3] },
          { label: 'Bar', data: [4, 5, 6] },
        ],
      }
    end
  end
end

describe ChartData::Base do
  subject(:chart_data) { FakeData.new(timeframe:) }

  let(:now) { Time.new('2024-04-17 11:00:00+02:00') }

  around { |example| travel_to(now, &example) }

  describe '#to_h' do
    subject(:to_h) { chart_data.to_h }

    let(:timeframe) { Timeframe.day }

    it { is_expected.to be_a(Hash) }
    it { is_expected.to include(:datasets, :labels) }
  end

  describe '#blank?' do
    subject(:blank) { chart_data.blank? }

    context 'when data present' do
      let(:timeframe) { Timeframe.day }

      it { is_expected.to be false }
    end

    context 'when data is missing' do
      let(:timeframe) { Timeframe.new('2024-05') }

      it { is_expected.to be true }
    end
  end
end
