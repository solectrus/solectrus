describe NoCurrentReading::Component, type: :component do
  let(:component) { described_class.new(data:) }
  let(:timeframe) { Timeframe.now }
  let(:data) do
    Sensor::Data::Single.new(
      {},
      timeframe:,
      times: { inverter_power: last_time },
    )
  end

  before do
    travel_to Time.zone.local(2026, 11, 17, 6, 0)
    render_inline(component) { 'Stats' }
  end

  context 'when the last reading is hours old' do
    let(:last_time) { Time.zone.local(2026, 11, 16, 14, 48) }

    it 'shows the time of the last reading in place of the stats' do
      expect(page).to have_text('No current readings')
      expect(page).to have_text('about 15 hours')
      expect(page).to have_css('[data-hides-chart]')
      expect(page).to have_no_text('Stats')
    end
  end

  context 'when only a sensor other than power delivers' do
    let(:last_time) { Time.zone.local(2026, 11, 16, 14, 48) }
    let(:data) do
      Sensor::Data::Single.new(
        {},
        timeframe:,
        times: { inverter_power: last_time, system_status: 1.minute.ago },
      )
    end

    it 'takes the time of the last power reading' do
      expect(page).to have_text('about 15 hours')
      expect(page).to have_no_text('Stats')
    end
  end

  context 'without a power reading in the day' do
    let(:last_time) { nil }

    it 'says so' do
      expect(page).to have_text('No current readings')
      expect(page).to have_text('No reading in the last 24 hours')
    end
  end

  context 'when the last reading is recent' do
    let(:last_time) { 1.minute.ago }

    it 'shows the stats' do
      expect(page).to have_text('Stats')
      expect(page).to have_no_css('[data-hides-chart]')
    end
  end

  context 'with a timeframe other than now' do
    let(:timeframe) { Timeframe.day }
    let(:last_time) { nil }

    it 'shows the stats' do
      expect(page).to have_text('Stats')
    end
  end
end
