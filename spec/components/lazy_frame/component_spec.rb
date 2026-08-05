describe LazyFrame::Component, type: :component do
  it 'renders a frame that fetches itself, with a spinner meanwhile' do
    frame =
      render_inline(described_class.new(id: 'detail', src: '/detail')).css(
        'turbo-frame',
      )

    aggregate_failures do
      expect(frame.attr('id').value).to eq('detail')
      expect(frame.attr('src').value).to eq('/detail')
      expect(frame.css('svg.loading')).to be_present
    end
  end

  it 'passes everything else through to the frame' do
    frame =
      render_inline(
        described_class.new(
          id: 'detail',
          src: '/detail',
          class: 'flex-1',
          target: '_top',
          loading: 'lazy',
        ),
      ).css('turbo-frame')

    aggregate_failures do
      expect(frame.attr('class').value).to eq('flex-1')
      expect(frame.attr('target').value).to eq('_top')
      expect(frame.attr('loading').value).to eq('lazy')
    end
  end

  it 'renders given contents instead of the spinner' do
    frame =
      render_inline(described_class.new(id: 'detail')) { 'Already here' }.css(
        'turbo-frame',
      )

    aggregate_failures do
      expect(frame.text).to include('Already here')
      expect(frame.attr('src')).to be_nil
      expect(frame.css('svg.loading')).to be_empty
    end
  end
end
