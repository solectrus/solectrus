describe ThemeConfig do
  let(:theme_config) { described_class.new(theme) }

  let(:env_light) { { 'UI_THEME' => 'light' } }
  let(:env_dark) { { 'UI_THEME' => 'dark' } }

  context 'when the ApplicationPolicy does not allow themes' do
    before { allow(ApplicationPolicy).to receive(:themes?).and_return(false) }

    describe '.setup' do
      before { described_class.setup(env_dark) }

      it 'ignores the given theme' do
        expect(Rails.application.config.theme).not_to be_static
      end

      it 'returns the light color' do
        expect(Rails.application.config.theme.color).to eq('#a5b4fc')
      end
    end
  end

  context 'when the ApplicationPolicy allows themes' do
    before { allow(ApplicationPolicy).to receive(:themes?).and_return(true) }

    describe '.setup' do
      before { described_class.setup(env_light) }

      it 'sets up the theme configuration' do
        expect(Rails.application.config.theme).to be_an_instance_of(
          described_class,
        )
      end
    end

    describe '.x' do
      subject { described_class.x }

      before { described_class.setup(env_light) }

      it { is_expected.to be_an_instance_of(described_class) }
    end

    shared_examples 'a valid theme' do |color:, static:, html_class:|
      it 'returns the correct color' do
        expect(theme_config.color).to eq(color)
      end

      it 'returns the correct static status' do
        expect(theme_config.static?).to be(static)
      end

      it 'returns the correct html_class' do
        expect(theme_config.html_class).to eq(html_class)
      end
    end

    context 'when the theme is light' do
      let(:theme) { env_light }

      it_behaves_like 'a valid theme',
                      color: '#a5b4fc',
                      static: true,
                      html_class: 'light'
    end

    context 'when the theme is dark' do
      let(:theme) { env_dark }

      it_behaves_like 'a valid theme',
                      color: '#1e1b4b',
                      static: true,
                      html_class: 'dark'
    end

    context 'when the theme is nil' do
      let(:theme) { {} }

      it_behaves_like 'a valid theme',
                      color: '#a5b4fc',
                      static: false,
                      html_class: nil
    end

    context 'when the theme is invalid' do
      let(:theme) { { 'UI_THEME' => 'invalid_theme' } }

      it 'raises an error' do
        expect { theme_config }.to raise_error(ThemeConfig::Error)
      end
    end
  end
end
