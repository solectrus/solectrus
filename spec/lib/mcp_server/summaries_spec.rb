describe McpServer::Summaries do
  # The summaries a query reads are built on demand, and before this the MCP
  # path was the one caller that never built them: it renders no page. So it
  # answered from whatever a browser happened to have built, and the running
  # day - which never has a summary until something asks - was simply absent.
  describe '.refresh' do
    let(:summarizer) { instance_double(Sensor::Summarizer, call: 0) }

    before { allow(Sensor::Summarizer).to receive(:new).and_return(summarizer) }

    context 'when every day is already summarized' do
      before do
        (1..3).each do |day|
          create_summary(date: "2024-06-0#{day}", values: [[:house_power, :sum, 1_000]])
        end
      end

      it 'builds nothing and says nothing' do
        expect(described_class.refresh(Timeframe.new('2024-06-01..2024-06-03'))).to eq({})
        expect(Sensor::Summarizer).not_to have_received(:new)
      end
    end

    context 'when a few days are missing' do
      it 'builds exactly the missing days' do
        result = described_class.refresh(Timeframe.new('2024-06-01..2024-06-03'))

        expect(result).to eq({})
        expect(Sensor::Summarizer).to have_received(:new).with(
          [Date.new(2024, 6, 1), Date.new(2024, 6, 2), Date.new(2024, 6, 3)],
        )
        expect(summarizer).to have_received(:call)
      end
    end

    # An instance whose history was never opened in a browser has thousands of
    # days pending. Building them inside one tool call would outlast any client
    # timeout, so the answer is given as it stands and says what it lacks.
    context 'when more days are missing than one call may build' do
      let(:timeframe) do
        last = Date.new(2024, 6, 1) + described_class::MAX_DAYS
        Timeframe.new("2024-06-01..#{last}")
      end

      it 'builds nothing and reports the gap' do
        result = described_class.refresh(timeframe)

        expect(Sensor::Summarizer).not_to have_received(:new)
        expect(result[:summary_note]).to include(
          "#{described_class::MAX_DAYS + 1} days",
        )
      end

      it 'names the way out rather than only the problem' do
        expect(described_class.refresh(timeframe)[:summary_note]).to include(
          'shorter timeframe',
        )
      end
    end

    # Hour timeframes and "now" are answered from raw measurements, so building
    # a summary for them would be work nothing reads.
    it 'builds nothing for a timeframe that reads no summaries' do
      expect(described_class.refresh(Timeframe.new('P24H'))).to eq({})
      expect(Sensor::Summarizer).not_to have_received(:new)
    end
  end
end
