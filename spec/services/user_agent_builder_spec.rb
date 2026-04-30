describe UserAgentBuilder, with_setup_id: 0 do
  let(:user_agent) { described_class.instance }

  describe '#to_s' do
    before do
      allow(Etc).to receive(:uname).and_return(
        sysname: 'Linux',
        release: '6.1.0',
        machine: 'aarch64',
      )

      allow(Rails.configuration.x.git).to receive(:commit_version).and_return(
        'v1.1.1',
      )

      allow(Rails.configuration.x).to receive(:app_name).and_return('SOLECTRUS')
    end

    it 'returns the user agent string' do
      expect(user_agent.to_s).to eq(
        'SOLECTRUS/v1.1.1 (Linux; aarch64; 6.1.0; 0)',
      )
    end

    context 'when Helios is available' do
      before { allow(HeliosCheck).to receive(:version).and_return('v0.1.1-4-g6bebca2') }

      it 'appends a helios token with version' do
        expect(user_agent.to_s).to eq(
          'SOLECTRUS/v1.1.1 (Linux; aarch64; 6.1.0; 0) HELIOS/v0.1.1-4-g6bebca2',
        )
      end
    end
  end
end
