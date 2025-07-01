describe ChartData::InverterPower do
  subject(:to_h) do
    described_class.new(timeframe:, sensor: :inverter_power_1).to_h
  end

  let(:now) { Time.new('2024-04-17 11:00:00+02:00') }

  around { |example| travel_to(now, &example) }

  before do
    influx_batch do
      # Fill last hour with data
      12.times do |i|
        add_influx_point name: measurement_inverter_power_1,
                         fields: {
                           field_inverter_power_1 => 28_000,
                         },
                         time: 1.hour.ago + (5.minutes * (i + 1))
      end
    end

    create_summary(
      date: now.to_date,
      values: [[:inverter_power_1, :sum, 28_000]],
    )
  end

  context 'when timeframe is current MONTH' do
    let(:timeframe) { Timeframe.month }

    it 'contains value' do
      expect(to_h.dig(:datasets, 0, :data, now.day - 1)).to eq(28_000)
    end
  end

  context 'when timeframe is NOW' do
    let(:timeframe) { Timeframe.now }

    it 'contains value' do
      expect(to_h.dig(:datasets, 0, :data).last).to eq(28_000)
    end
  end

  describe '#valid_parts?' do
    subject(:valid_parts?) { chart_data.send(:valid_parts?, total, parts) } # rubocop:disable Style/Send

    let(:chart_data) { described_class.new(timeframe: Timeframe.week) }

    context 'when total is nil' do
      let(:total) { nil }
      let(:parts) { [100, 200] }

      it { is_expected.to be true }
    end

    context 'when total is zero' do
      let(:total) { 0 }
      let(:parts) { [100, 200] }

      it { is_expected.to be false }
    end

    context 'when parts array is empty' do
      let(:total) { 300 }
      let(:parts) { [] }

      it { is_expected.to be false }
    end

    context 'when all parts are nil' do
      let(:total) { 300 }
      let(:parts) { [nil, nil, nil] }

      it { is_expected.to be false }
    end

    context 'when some parts are nil' do
      let(:total) { 300 }

      context 'when remaining parts sum up correctly' do
        let(:parts) { [100, nil, 200] } # 100 + 200 = 300, ratio = 100%

        it { is_expected.to be true }
      end

      context 'when remaining parts do not sum up correctly' do
        let(:parts) { [100, nil, 50] } # 100 + 50 = 150, ratio = 50%

        it { is_expected.to be false }
      end
    end

    context 'when parts sum up correctly' do
      let(:total) { 300 }

      context 'with exact match' do
        let(:parts) { [100, 200] } # 100 + 200 = 300, ratio = 100%

        it { is_expected.to be true }
      end

      context 'when within 1% tolerance' do
        let(:parts) { [98, 201] } # 98 + 201 = 299, ratio = 99.67% (rounds to 100%)

        it { is_expected.to be true }
      end

      context 'when at exactly 99% threshold' do
        let(:parts) { [297] } # 297 / 300 = 99%

        it { is_expected.to be true }
      end
    end

    context 'when parts do not sum up correctly' do
      let(:total) { 300 }

      context 'when sum is too low' do
        let(:parts) { [100, 100] } # 100 + 100 = 200, ratio = 66.67%

        it { is_expected.to be false }
      end

      context 'when just below 99% threshold' do
        let(:parts) { [295] } # 295 / 300 = 98.33% (rounds to 98%)

        it { is_expected.to be false }
      end
    end
  end
end
