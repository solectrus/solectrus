describe SummaryBuilder::Component, type: :component do
  subject(:frames) do
    render_inline(
      described_class.new(timeframe: Timeframe.new('2024'), missing_or_stale_days: days),
    ).css('turbo-frame')
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

  # A trailing chunk covers fewer days, so the bar must not claim a full share
  it 'weights each frame by the days it covers' do
    size = Sensor::Summarizer::CHUNK_SIZE
    full, rest = days.size.divmod(size)

    expect(frames.pluck('style')).to eq(
      (["flex: #{size}"] * full) + (rest.zero? ? [] : ["flex: #{rest}"]),
    )
  end

  context 'with only a few days' do
    let(:days) { [Date.new(2024, 1, 1), Date.new(2024, 1, 2)] }

    it 'shows a spinner instead of the progress bar' do
      html = render_inline(
        described_class.new(timeframe: Timeframe.new('2024'), missing_or_stale_days: days),
      )

      expect(html.css('svg.loading')).to be_present
      expect(html.css('turbo-frame').size).to eq(1)
    end
  end
end
