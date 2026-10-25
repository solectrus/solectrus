describe Ui::LazyRows::Component, type: :component do
  # The parts of a Pagy object that the component reads
  let(:pagy_class) do
    Struct.new(:page, :next) do
      def page_url(_which) = "/list?page=#{self.next}"
    end
  end

  it 'renders the rows and a lazy frame for the next page' do
    render_inline(described_class.new(prefix: 'rows_', pagy: pagy_class.new(1, 2))) { 'Row 1' }

    aggregate_failures do
      expect(page).to have_text('Row 1')
      expect(page).to have_css('turbo-frame#rows_2[src="/list?page=2"][loading="lazy"][target="_top"]')
      expect(page).to have_css('turbo-frame#rows_2 [role="status"]', text: 'Loading more entries')
    end
  end

  it 'renders a further page in its own frame, without a next one at the end' do
    render_inline(described_class.new(prefix: 'rows_', pagy: pagy_class.new(3, nil), frame: true)) { 'Row 51' }

    aggregate_failures do
      expect(page).to have_css('turbo-frame#rows_3', text: 'Row 51')
      expect(page).to have_no_css('turbo-frame[src]')
    end
  end

  it 'tells a request of a further page by its frame' do
    request = vc_test_request
    request.headers['Turbo-Frame'] = 'rows_2'

    expect(described_class.request?(request, 'rows_')).to be(true)
  end
end
