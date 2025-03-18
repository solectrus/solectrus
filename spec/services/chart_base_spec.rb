describe ChartBase do
  before { travel_to Date.new(2025, 3, 17) }

  describe '#dates' do
    subject do
      described_class.new(sensors: ['inverter_power']).dates(timeframe)
    end

    context 'when timeframe is a day' do
      let(:timeframe) { Timeframe.new '2025-02-17' }

      it { is_expected.to be_nil }
    end

    context 'when timeframe is a week' do
      let(:timeframe) { Timeframe.new '2025-W03' }

      it { is_expected.to eq(Date.new(2025, 1, 13)..Date.new(2025, 1, 19)) }
    end

    context 'when timeframe is some days' do
      let(:timeframe) { Timeframe.new 'P6D' }

      it { is_expected.to eq(Date.new(2025, 3, 12)..Date.new(2025, 3, 16)) }
    end

    context 'when timeframe is a month' do
      let(:timeframe) { Timeframe.new '2025-02' }

      it { is_expected.to eq(Date.new(2025, 2, 1)..Date.new(2025, 2, 28)) }
    end

    context 'when timeframe is some months' do
      let(:timeframe) { Timeframe.new 'P4M' }

      it do
        is_expected.to eq(
          [
            Date.new(2024, 11, 1),
            Date.new(2024, 12, 1),
            Date.new(2025, 1, 1),
            Date.new(2025, 2, 1),
          ],
        )
      end
    end

    context 'when timeframe is a year' do
      let(:timeframe) { Timeframe.new '2025' }

      it do
        is_expected.to eq [
             Date.new(2025, 1, 1),
             Date.new(2025, 2, 1),
             Date.new(2025, 3, 1),
             Date.new(2025, 4, 1),
             Date.new(2025, 5, 1),
             Date.new(2025, 6, 1),
             Date.new(2025, 7, 1),
             Date.new(2025, 8, 1),
             Date.new(2025, 9, 1),
             Date.new(2025, 10, 1),
             Date.new(2025, 11, 1),
             Date.new(2025, 12, 1),
           ]
      end
    end

    context 'when timeframe is some years' do
      let(:timeframe) { Timeframe.new 'P4Y' }

      it do
        is_expected.to eq(
          [
            Date.new(2021, 1, 1),
            Date.new(2022, 1, 1),
            Date.new(2023, 1, 1),
            Date.new(2024, 1, 1),
          ],
        )
      end
    end

    context 'when timeframe is all' do
      let(:timeframe) { Timeframe.new 'all' }

      it do
        is_expected.to eq [
             Date.new(2020, 1, 1),
             Date.new(2021, 1, 1),
             Date.new(2022, 1, 1),
             Date.new(2023, 1, 1),
             Date.new(2024, 1, 1),
             Date.new(2025, 1, 1),
           ]
      end
    end
  end
end
