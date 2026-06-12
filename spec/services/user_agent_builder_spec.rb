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
        'v1.2.1',
      )

      allow(Rails.configuration.x).to receive(:app_name).and_return('SOLECTRUS')

      # Default: all optional service tokens disabled so each context can
      # opt-in to exactly the one it wants to verify
      allow(ServiceVersions).to receive_messages(
        influxdb: nil,
        postgresql: nil,
        redis: nil,
      )

      allow(UpdateCheck).to receive(:profile_code).and_return(0)
    end

    it 'starts with the application, version and system info' do
      expect(user_agent.to_s).to start_with(
        'SOLECTRUS/v1.2.1 (Linux; aarch64; 6.1.0; 0)',
      )
    end

    it 'includes the profile code' do
      expect(user_agent.to_s).to include('FEATURES/0')
    end

    context 'with a non-zero profile code' do
      before { allow(UpdateCheck).to receive(:profile_code).and_return(1) }

      it 'includes it in the user agent' do
        expect(user_agent.to_s).to include('FEATURES/1')
      end
    end

    context 'when Helios is available' do
      before { allow(HeliosCheck).to receive(:version).and_return('v0.1.1-4-g6bebca2') }

      it 'appends a helios token with version' do
        expect(user_agent.to_s).to include('HELIOS/v0.1.1-4-g6bebca2')
      end
    end

    context 'when InfluxDB version is available' do
      before { allow(ServiceVersions).to receive(:influxdb).and_return(Gem::Version.new('2.8.0')) }

      it 'appends an influxdb token with version' do
        expect(user_agent.to_s).to include('INFLUXDB/2.8.0')
      end
    end

    context 'when PostgreSQL version is available' do
      before { allow(ServiceVersions).to receive(:postgresql).and_return(Gem::Version.new('16.1')) }

      it 'appends a postgresql token with version' do
        expect(user_agent.to_s).to include('POSTGRESQL/16.1')
      end
    end

    context 'when Redis version is available' do
      before { allow(ServiceVersions).to receive(:redis).and_return(Gem::Version.new('7.4.0')) }

      it 'appends a redis token with version' do
        expect(user_agent.to_s).to include('REDIS/7.4.0')
      end
    end

    context 'when all service versions are available' do
      before do
        allow(HeliosCheck).to receive(:version).and_return('v0.1.1-4-g6bebca2')
        allow(ServiceVersions).to receive_messages(
          influxdb: Gem::Version.new('2.8.0'),
          postgresql: Gem::Version.new('16.1'),
          redis: Gem::Version.new('7.4.0'),
        )
      end

      it 'appends all service tokens with versions' do
        expect(user_agent.to_s)
          .to include('HELIOS/v0.1.1-4-g6bebca2')
          .and include('INFLUXDB/2.8.0')
          .and include('POSTGRESQL/16.1')
          .and include('REDIS/7.4.0')
      end
    end
  end
end
