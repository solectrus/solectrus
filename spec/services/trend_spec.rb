describe Trend do
  let(:trend) { described_class.new(sensor:, timeframe:, current_value:) }

  let(:current_value) { 0 }

  before { travel_to Date.new(2025, 5, 10) }

  describe '#base_timeframe' do
    subject { trend.base_timeframe.to_s }

    context 'when sensor is inverter_power' do
      let(:sensor) { :inverter_power }

      context 'when timeframe is a month' do
        let(:timeframe) { Timeframe.new('2025-04') }

        it { is_expected.to eq('2024-04') }
      end

      context 'when timeframe is a year' do
        let(:timeframe) { Timeframe.new('2025') }

        it { is_expected.to eq('2024-01-01..2024-05-10') }
      end
    end

    context 'when sensor is house_power' do
      let(:sensor) { :house_power }

      context 'when timeframe is a month' do
        let(:timeframe) { Timeframe.new('2025-04') }

        it { is_expected.to eq('2024-04') }
      end

      context 'when timeframe is a year' do
        let(:timeframe) { Timeframe.new('2025') }

        it { is_expected.to eq('2024-01-01..2024-05-10') }
      end
    end
  end

  describe '#base_value' do
    subject(:base_value) { trend.base_value }

    let(:sensor) { :inverter_power }
    let(:timeframe) { Timeframe.new('2025-04') }

    before do
      create_summary(
        date: Date.new(2024, 4, 1),
        values: [[:inverter_power_1, :sum, 3000]],
      )
      create_summary(
        date: Date.new(2024, 4, 2),
        values: [[:inverter_power_1, :sum, 2000]],
      )
      create_summary(
        date: Date.new(2024, 4, 30),
        values: [[:inverter_power_1, :sum, 1000]],
      )
    end

    it { is_expected.to eq(6000) }
  end

  describe '#factor und #percent' do
    let(:sensor) { :inverter_power }
    let(:timeframe) { Timeframe.new('2025-04') }

    before { allow(trend).to receive(:base_value).and_return(1000) }

    {
      [2000, 'greater'] => {
        factor: 2,
        percent: 100,
      },
      [500, 'less'] => {
        factor: 0.5,
        percent: -50,
      },
      [1000, 'equal'] => {
        factor: 1,
        percent: 0,
      },
    }.each do |(value, msg), expected|
      context "when #{msg} than sum" do
        let(:current_value) { value }

        it 'calculates factor and percent correctly' do
          expect(trend.factor).to eq(expected[:factor])
          expect(trend.percent).to eq(expected[:percent])
        end
      end
    end
  end
end
