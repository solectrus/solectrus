describe VersionInfo::Component, type: :component do
  subject(:component) do
    described_class.new(
      current_version: 'v0.12.0-89-gc0ffee',
      commit_time: Time.current,
      github_url: 'https://github.com/user/repo',
    )
  end

  describe '#latest_version' do
    it 'returns the latest version', vcr: { cassette_name: 'version' } do
      expect(component.latest_version).to eq 'v0.14.5'
    end
  end

  describe '#outdated?' do
    subject { component.outdated? }

    before do
      api = instance_double(UpdateCheck)
      allow(UpdateCheck).to receive(:instance).and_return(api)
      allow(api).to receive(:latest_version).and_return(latest_version)
    end

    context 'when the latest version matches the current version' do
      let(:latest_version) { 'v0.12.0' }

      it { is_expected.to be false }
    end

    context 'when the latest version is newer' do
      let(:latest_version) { 'v9.9.999' }

      it { is_expected.to be true }
    end

    context 'when the latest version is older' do
      let(:latest_version) { 'v0.11.0' }

      it { is_expected.to be false }
    end

    context 'when the latest version is unknown' do
      let(:latest_version) { 'unknown' }

      it { is_expected.to be false }
    end
  end

  describe '#version_valid?' do
    subject { component.version_valid? }

    before do
      api = instance_double(UpdateCheck)
      allow(UpdateCheck).to receive(:instance).and_return(api)
      allow(api).to receive(:latest_version).and_return(latest_version)
    end

    context 'when the latest version is present' do
      let(:latest_version) { 'v1.2.3' }

      it { is_expected.to be true }
    end

    context 'when the latest version is unknown' do
      let(:latest_version) { 'unknown' }

      it { is_expected.to be false }
    end
  end

  describe '#latest_release_url', vcr: { cassette_name: 'version' } do
    subject { component.latest_release_url }

    it do
      is_expected.to eq 'https://github.com/solectrus/solectrus/releases/tag/v0.14.5'
    end
  end
end
