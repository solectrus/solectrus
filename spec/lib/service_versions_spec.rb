describe ServiceVersions do
  describe '.fetch_influxdb' do
    subject(:fetch_influxdb) { described_class.fetch_influxdb }

    let(:health) { instance_double(InfluxDB2::HealthCheck, version: raw_version) }

    before { allow(Influx).to receive(:health).and_return(health) }

    context 'when Influx reports a recent version' do
      let(:raw_version) { 'v2.8.0' }

      it { is_expected.to eq(Gem::Version.new('2.8.0')) }
    end

    context 'when Influx reports a version without v-prefix' do
      let(:raw_version) { '2.8.0' }

      it { is_expected.to eq(Gem::Version.new('2.8.0')) }
    end

    context 'when Influx reports a version below the recommended one' do
      let(:raw_version) { 'v2.6.0' }

      it 'returns the version and logs a warning' do
        allow(Rails.logger).to receive(:warn)
        expect(fetch_influxdb).to eq(Gem::Version.new('2.6.0'))
        expect(Rails.logger).to have_received(:warn).with(/upgrading to 2.8/)
      end
    end

    context 'when the health probe raises' do
      let(:raw_version) { nil }

      before do
        allow(Influx).to receive(:health).and_raise(StandardError, 'boom')
        allow(Rails.logger).to receive(:error)
      end

      it { is_expected.to be_nil }
    end
  end

  describe '.fetch_postgresql' do
    subject { described_class.fetch_postgresql }

    context 'when the connection returns a server_version string' do
      before do
        allow(ApplicationRecord.connection).to receive(:select_value)
          .with('SHOW server_version')
          .and_return('16.1 (Debian 16.1-1.pgdg120+1)')
      end

      it { is_expected.to eq(Gem::Version.new('16.1')) }
    end

    context 'when the connection raises' do
      before do
        allow(ApplicationRecord.connection).to receive(:select_value)
          .with('SHOW server_version')
          .and_raise(ActiveRecord::ConnectionNotEstablished)
      end

      it { is_expected.to be_nil }
    end
  end

  describe '.at_least?' do
    subject { described_class.at_least?(:influxdb, '2.2') }

    around do |example|
      original = described_class.instance_variable_get(:@influxdb)
      example.run
    ensure
      described_class.instance_variable_set(:@influxdb, original)
    end

    context 'when the version is greater' do
      before { described_class.instance_variable_set(:@influxdb, Gem::Version.new('2.8.0')) }

      it { is_expected.to be true }
    end

    context 'when the version is exactly equal' do
      before { described_class.instance_variable_set(:@influxdb, Gem::Version.new('2.2')) }

      it { is_expected.to be true }
    end

    context 'when the version is older' do
      before { described_class.instance_variable_set(:@influxdb, Gem::Version.new('2.1.0')) }

      it { is_expected.to be false }
    end

    context 'when the version is unknown' do
      before { described_class.instance_variable_set(:@influxdb, nil) }

      it { is_expected.to be false }
    end
  end

  describe '.fetch_redis' do
    subject { described_class.fetch_redis }

    context 'when Rails.cache is a Redis cache' do
      let(:redis) { instance_double(Redis, info: { 'redis_version' => '7.4.0' }) }
      let(:pool) { instance_double(ConnectionPool) }
      let(:redis_cache) do
        instance_double(ActiveSupport::Cache::RedisCacheStore, redis: pool)
      end

      before do
        allow(Rails).to receive(:cache).and_return(redis_cache)
        allow(pool).to receive(:with).and_yield(redis)
      end

      it { is_expected.to eq(Gem::Version.new('7.4.0')) }
    end

    context 'when Rails.cache is not Redis-backed' do
      it { is_expected.to be_nil }
    end

    context 'when querying Redis raises' do
      let(:pool) { instance_double(ConnectionPool) }
      let(:redis_cache) do
        instance_double(ActiveSupport::Cache::RedisCacheStore, redis: pool)
      end

      before do
        allow(Rails).to receive(:cache).and_return(redis_cache)
        allow(pool).to receive(:with).and_raise(Redis::CannotConnectError)
      end

      it { is_expected.to be_nil }
    end
  end
end
