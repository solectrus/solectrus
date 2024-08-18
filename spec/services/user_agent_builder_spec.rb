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
        'v1.0.0',
      )
    end

    it 'returns the user agent string' do
      expect(user_agent.to_s).to eq(
        'SOLECTRUS/v1.0.0 (Linux; aarch64; 6.1.0; 0)',
      )
    end
  end
end
