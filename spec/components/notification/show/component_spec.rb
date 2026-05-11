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

    context 'when the body contains a link to solectrus.de' do
      let(:body) do
        '<a href="https://solectrus.de/blog/foo">Foo</a>'
      end

      it 'appends UTM parameters' do
        render_inline(component)

        href = page.find('a', text: 'Foo')['href']
        expect(href).to start_with('https://solectrus.de/blog/foo?')
        expect(href).to include('utm_source=solectrus-app')
        expect(href).to include('utm_medium=notification')
      end
    end

    context 'when the body contains a link to a solectrus.de subdomain' do
      let(:body) do
        '<a href="https://docs.solectrus.de/setup">Docs</a>'
      end

      it 'appends UTM parameters' do
        render_inline(component)

        href = page.find('a', text: 'Docs')['href']
        expect(href).to include('utm_source=solectrus-app')
        expect(href).to include('utm_medium=notification')
      end
    end

    context 'when a foreign host merely ends with the solectrus.de string' do
      let(:body) do
        '<a href="https://evilsolectrus.de/phish">Trap</a>'
      end

      it 'does not append UTM parameters' do
        render_inline(component)

        expect(page.find('a', text: 'Trap')['href']).to eq(
          'https://evilsolectrus.de/phish',
        )
      end
    end

    context 'when the solectrus.de link already carries utm_campaign' do
      let(:body) do
        '<a href="https://solectrus.de/blog/foo?utm_campaign=helios">Foo</a>'
      end

      it 'preserves existing params and adds the missing ones' do
        render_inline(component)

        href = page.find('a', text: 'Foo')['href']
        expect(href).to include('utm_campaign=helios')
        expect(href).to include('utm_source=solectrus-app')
        expect(href).to include('utm_medium=notification')
      end
    end

    context 'when the solectrus.de link already sets utm_source' do
      let(:body) do
        '<a href="https://solectrus.de/?utm_source=custom">X</a>'
      end

      it 'keeps the existing utm_source untouched' do
        render_inline(component)

        href = page.find('a', text: 'X')['href']
        expect(href).to include('utm_source=custom')
        expect(href).not_to include('utm_source=solectrus-app')
      end
    end

    context 'when the body contains a link to a different host' do
      let(:body) { '<a href="https://example.com/foo">Foo</a>' }

      it 'does not append UTM parameters' do
        render_inline(component)

        expect(page.find('a', text: 'Foo')['href']).to eq(
          'https://example.com/foo',
        )
      end
    end

    context 'when the body contains a relative link' do
      let(:body) { '<a href="/somewhere">Local</a>' }

      it 'leaves the href unchanged' do
        render_inline(component)

        expect(page.find('a', text: 'Local')['href']).to end_with('/somewhere')
      end
    end
  end
end
