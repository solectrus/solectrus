describe Trend do
  subject(:trend) do
    described_class.new(sensor:, timeframe:, current_value:, base:)
  end

  before { travel_to Date.new(2025, 5, 10) }

  let(:current_value) { 0 }

  describe '#base_timeframe' do
    subject { trend.base_timeframe.to_s }

    let(:sensor) { :inverter_power }

    context 'when base is previous_year' do
      let(:base) { :previous_year }

      context 'when timeframe is a month from the past' do
        let(:timeframe) { Timeframe.new('2025-04') }

        it { is_expected.to eq('2024-04') }
      end

      context 'when timeframe is current month' do
        let(:timeframe) { Timeframe.new('2025-05') }

        it { is_expected.to eq('2024-05-01..2024-05-10') }
      end

      context 'when timeframe is last 30 days' do
        let(:timeframe) { Timeframe.new('P30D') } # 2025-04-10..2025-05-09

        it { is_expected.to eq('2024-04-10..2024-05-09') }
      end

      context 'when timeframe is a year' do
        let(:timeframe) { Timeframe.new('2025') }

        it { is_expected.to eq('2024-01-01..2024-05-10') }
      end

      context 'when timeframe is last 12 months' do
        let(:timeframe) { Timeframe.new('P12M') } # 2024-05-01..2025-04-30

        it { is_expected.to eq('2023-05-01..2024-04-30') }
      end

      context 'when timeframe is last 365 days' do
        let(:timeframe) { Timeframe.new('P365D') } # 2024-05-10..2025-05-09

        it { is_expected.to eq('2023-05-10..2024-05-09') }
      end
    end

    context 'when base is previous_period' do
      let(:base) { :previous_period }

      context 'when timeframe is a month' do
        let(:timeframe) { Timeframe.new('2025-04') }

        it { is_expected.to eq('2025-03') }
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
    let(:base) { :previous_year }

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
    let(:base) { :previous_year }

    before do
      create_summary(
        date: Date.new(2024, 4, 1),
        values: [[:inverter_power_1, :sum, 1000]],
      )
    end

    it 'has a base_value of 1000' do
      expect(trend.base_value).to eq(1000)
    end

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
