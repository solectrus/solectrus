describe Summarizer do
  describe '.perform!' do
    subject(:perform) { described_class.new(timeframe:).perform_now! }

    context 'when summary does not exist' do
      let(:timeframe) { Timeframe.day }

      it { expect { perform }.to change(Summary, :count).by(1) }
    end

    context 'when fresh summary exists' do
      let(:timeframe) { Timeframe.day }

      let(:last_updated_at) { 1.minute.ago }

      let!(:existing_summary) do
        Summary.create!(date: Date.current, updated_at: last_updated_at)
      end

      it { expect { perform }.not_to change(Summary, :count) }

      it do
        expect { perform }.not_to(change { existing_summary.reload.updated_at })
      end
    end

    context 'when stale summary exists' do
      let(:timeframe) { Timeframe.day }

      let(:last_updated_at) { (Summary::CURRENT_TOLERANCE + 1).minutes.ago }

      let!(:existing_summary) do
        Summary.create!(date: Date.current, updated_at: last_updated_at)
      end

      it { expect { perform }.not_to change(Summary, :count) }

      it do
        expect { perform }.to(change { existing_summary.reload.updated_at })
      end
    end

    context 'when Influx data is present' do
      let(:timeframe) { Timeframe.new('2024-10-01') }

      before do
        influx_batch do
          # Fill one hour (12:00 - 13:00) with 10 kW power
          13.times do |i|
            time = timeframe.date.middle_of_day + (5.minutes * i)

            add_influx_point name: measurement_inverter_power,
                             fields: {
                               field_inverter_power => 10_000,
                             },
                             time:
          end
        end

        perform
      end

      it 'creates summary' do
        expect(Summary.count).to eq(1)
      end

      it 'creates summary with correct values' do
        summary = Summary.last

        expect(summary.date).to eq(timeframe.date)
        expect(summary.values.first.attributes).to include(
          'date' => timeframe.date,
          'field' => 'inverter_power',
          'aggregation' => 'sum',
          'value' => 10_000,
        )
      end
    end
  end
end
