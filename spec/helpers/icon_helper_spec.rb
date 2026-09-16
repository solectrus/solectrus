describe IconHelper do
  describe '#icon' do
    subject(:svg) { helper.icon(name, **options) }

    let(:name) { 'gear' }
    let(:options) { {} }

    it 'renders an inline SVG' do
      expect(svg).to start_with('<svg ').and end_with('</svg>')
    end

    # The Font Awesome stylesheet is still what sizes and aligns an icon, and it
    # reaches them through this class. Losing it would leave every icon unstyled.
    it 'carries the Font Awesome classes' do
      expect(svg).to include('svg-inline--fa', 'fa-gear')
    end

    it 'takes the path out of the icon set' do
      expect(svg).to include(IconSet.find('gear').path)
    end

    it 'colors the path with currentColor, so the icon follows the text' do
      expect(svg).to include('fill="currentColor"')
    end

    it 'hides the icon from assistive technology' do
      expect(svg).to include('aria-hidden="true"')
    end

    context 'with extra classes as a string' do
      let(:options) { { class: 'fa-lg text-red-500' } }

      it 'appends them' do
        expect(svg).to include('svg-inline--fa fa-gear fa-lg text-red-500')
      end
    end

    # Callers pass a conditional class next to a fixed one, and the nil of an
    # unmet condition must not land in the class list.
    context 'with extra classes as an array holding a nil' do
      let(:options) { { class: ['fa-lg', nil] } }

      it 'skips the nil' do
        expect(svg).to include('class="svg-inline--fa fa-gear fa-lg"')
      end
    end

    context 'with another attribute' do
      let(:options) { { data: { view_toggle_target: 'icon' } } }

      it 'passes it through' do
        expect(svg).to include('data-view-toggle-target="icon"')
      end
    end

    context 'with an unknown icon' do
      let(:name) { 'no-such-icon' }

      it 'names the file to fix' do
        expect { svg }.to raise_error(
          IconSet::UnknownIcon,
          %r{config/icons\.yml},
        )
      end
    end

    context 'with an alias of an icon' do
      let(:name) { 'home' }

      # `home` is an alias of `house`. The generator refuses aliases, so only the
      # canonical name ever reaches the app.
      it 'is unknown' do
        expect { svg }.to raise_error(IconSet::UnknownIcon)
      end
    end
  end
end
