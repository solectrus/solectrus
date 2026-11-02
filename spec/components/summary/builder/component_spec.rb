describe Summary::Builder::Component, type: :component do
  subject(:frames) { rendered.css('turbo-frame') }

  let(:rendered) do
    render_inline(
      described_class.new(timeframe: Timeframe.new('2024'), missing_or_stale_days: days),
    )
  end

  let(:days) { (Date.new(2024, 1, 1)..Date.new(2024, 1, 31)).to_a }

  # One request per day would spend most of its time on the request itself
  it 'asks for a batch of days per frame' do
    expect(frames.size).to eq((days.size.to_f / Sensor::Summarizer::CHUNK_SIZE).ceil)
  end

  it 'covers every day exactly once, in order' do
    ranges =
      frames.map do |frame|
        frame['data-src'].match(
          %r{/summaries/(?<from>[\d-]+)\?to=(?<to>[\d-]+)},
        )
      end

    covered = ranges.flat_map { |m| (Date.parse(m[:from])..Date.parse(m[:to])).to_a }
    expect(covered).to eq(days)
  end

  # A trailing chunk covers fewer days, so it must not claim a full share
  it 'counts the days of each frame' do
    size = Sensor::Summarizer::CHUNK_SIZE
    full, rest = days.size.divmod(size)

    expect(frames.pluck('data-days')).to eq(
      ([size.to_s] * full) + (rest.zero? ? [] : [rest.to_s]),
    )
  end

  it 'shows the percentage and the time left below the bar' do
    expect(rendered.css('[data-sequential-frames-target=percent]')).to be_present
  end

  # A single frame goes from nothing to all at once
  context 'with a single frame' do
    let(:days) { (Date.new(2024, 1, 1)..Date.new(2024, 1, 7)).to_a }

    it 'shows the bar alone' do
      expect(rendered.css('[role=progressbar]')).to be_present
      expect(rendered.css('[data-sequential-frames-target=percent]')).to be_empty
    end
  end
end
