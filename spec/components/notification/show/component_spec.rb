describe Notification::Show::Component, type: :component do
  subject(:component) { described_class.new(notification:) }

  let(:notification) do
    Notification.create!(
      title: 'Important Message',
      body:,
      published_at: 1.day.ago,
    )
  end

  describe 'rendered body' do
    context 'when the body contains a link' do
      let(:body) do
        '<p>Siehe <a href="https://example.com">Details</a>.</p>'
      end

      it 'forces the link to open in a new tab' do
        render_inline(component)

        link = page.find('a', text: 'Details')
        expect(link['target']).to eq('_blank')
        expect(link['rel']).to eq('noopener')
        expect(link['href']).to eq('https://example.com')
      end
    end

    context 'when the body contains multiple links' do
      let(:body) do
        '<a href="https://a.example">A</a> und <a href="https://b.example">B</a>'
      end

      it 'adds target and rel attributes to every link' do
        render_inline(component)

        expect(
          page.all('a[target="_blank"][rel="noopener"]').size,
        ).to eq(2)
      end
    end

    context 'when the body contains no links' do
      let(:body) { '<p>Nur Text, kein Link.</p>' }

      it 'renders the text without adding link attributes' do
        render_inline(component)

        expect(page).to have_text('Nur Text, kein Link.')
        expect(page).to have_no_css('a[target]')
      end
    end

    context 'when the body contains a script tag' do
      let(:body) { '<p>OK</p><script>alert(1)</script>' }

      it 'strips the script tag via sanitize' do
        render_inline(component)

        expect(page).to have_text('OK')
        expect(page.native.to_html).not_to include('<script>')
      end
    end
  end
end
