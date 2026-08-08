describe McpServer::Tools::Prices do
  before do
    Price.create!(name: 'electricity', starts_at: '2024-01-01', value: 0.30)
    Price.create!(
      name: 'electricity',
      starts_at: '2025-01-01',
      value: 0.35,
      note: 'New contract',
    )
    Price.create!(name: 'feed_in', starts_at: '2024-01-01', value: 0.08)
  end

  describe '.call' do
    it 'returns the price effective on the given date plus history' do
      response = described_class.call(server_context: nil, date: '2025-06-15')

      expect(response.error?).to be(false)
      data = JSON.parse(response.content.first[:text], symbolize_names: true)

      electricity = data[:prices].find { _1[:name] == 'electricity' }
      expect(electricity[:effective]).to eq(0.35)
      expect(electricity[:unit]).to eq("#{Rails.configuration.x.currency}/kWh")
      expect(electricity[:history].pluck(:value)).to include(0.35, 0.30)

      latest = electricity[:history].find { _1[:starts_at] == '2025-01-01' }
      expect(latest[:note]).to eq('New contract')

      feed_in = data[:prices].find { _1[:name] == 'feed_in' }
      expect(feed_in[:effective]).to eq(0.08)
    end

    # "current" claimed today's tariff for a value that follows `date`, so a
    # question about 2024 came back labelled as the price now.
    it 'names the value after the date it belongs to, not after today' do
      response = described_class.call(server_context: nil, date: '2024-06-15')

      data = JSON.parse(response.content.first[:text], symbolize_names: true)
      electricity = data[:prices].find { _1[:name] == 'electricity' }

      expect(electricity).not_to have_key(:current)
      expect(electricity[:effective]).to eq(0.30)
      expect(data[:date]).to eq('2024-06-15')
    end

    # A date before the first configured tariff has no price to be effective,
    # and the tool says so instead of reaching forward to the oldest entry.
    # The description now states this, so the behaviour is pinned next to it.
    it 'reports null where the history begins after the date' do
      before_any_price = (Price.minimum(:starts_at) - 1.day).iso8601
      response = described_class.call(server_context: nil, date: before_any_price)

      data = JSON.parse(response.content.first[:text], symbolize_names: true)
      electricity = data[:prices].find { _1[:name] == 'electricity' }

      expect(electricity).to have_key(:effective)
      expect(electricity[:effective]).to be_nil
    end

    it 'sorts the history by value and limits it' do
      response =
        described_class.call(
          server_context: nil,
          sort: 'value',
          order: 'desc',
          limit: 1,
        )

      data = JSON.parse(response.content.first[:text], symbolize_names: true)
      expect(data).to include(sort: 'value', order: 'desc', limit: 1)

      electricity = data[:prices].find { _1[:name] == 'electricity' }
      expect(electricity[:history].size).to eq(1)
      expect(electricity[:history].first[:value]).to eq(0.35)
      # effective is still derived from the full history, not the limited slice
      expect(electricity[:effective]).to eq(0.35)
    end

    it 'clamps the limit into 1..100' do
      response = described_class.call(server_context: nil, limit: 0)

      data = JSON.parse(response.content.first[:text], symbolize_names: true)
      expect(data[:limit]).to eq(1)
      expect(data[:prices].first[:history].size).to eq(1)
    end

    it 'defaults to today when no date is given' do
      response = described_class.call(server_context: nil)

      data = JSON.parse(response.content.first[:text], symbolize_names: true)
      expect(data[:date]).to eq(Date.current.iso8601)
    end

    it 'reports an invalid date' do
      response = described_class.call(server_context: nil, date: 'not-a-date')

      expect(response.error?).to be(true)
      expect(response.content.first[:text]).to include('Invalid date')
    end

    # The history used to be cut from the newest end regardless of `date`, so a
    # question about 2024 came back with `effective` from 2024 next to a list
    # holding only 2025 - the number above the list appeared nowhere in it.
    context 'with a date the history reaches past' do
      def electricity(**)
        response = described_class.call(server_context: nil, **)
        data = JSON.parse(response.content.first[:text], symbolize_names: true)

        data[:prices].find { _1[:name] == 'electricity' }
      end

      it 'cuts the history at the date, not at the newest entry' do
        entry = electricity(date: '2024-06-15', limit: 1)

        expect(entry[:effective]).to eq(0.30)
        expect(entry[:history].pluck(:starts_at)).to eq(%w[2024-01-01])
      end

      it 'keeps `effective` in the history even at a limit of 1' do
        entry = electricity(date: '2024-06-15', limit: 1)

        expect(entry[:history].pluck(:value)).to include(entry[:effective])
      end

      it 'lists a tariff starting after the date as upcoming, not as history' do
        entry = electricity(date: '2024-06-15')

        expect(entry[:history].pluck(:starts_at)).not_to include('2025-01-01')
        expect(entry[:upcoming].pluck(:starts_at)).to eq(%w[2025-01-01])
      end

      it 'omits `upcoming` where nothing is pending' do
        entry = electricity(date: '2025-06-15')

        expect(entry).not_to have_key(:upcoming)
      end

      it 'still orders what it kept' do
        dates = electricity(date: '2025-06-15', order: 'asc')[:history].pluck(:starts_at)

        expect(dates).to eq(dates.sort)
        expect(dates.last).to eq('2025-01-01')
      end
    end
  end
end
