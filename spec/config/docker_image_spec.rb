describe DockerImage do
  # The build writes a file into the root of the Docker image, and a working
  # copy carries every file of the repository but that one.
  describe '.built?' do
    subject(:built?) { described_class.built?(dir.to_s) }

    let(:dir) { Pathname.new(Dir.mktmpdir) }

    after { dir.rmtree }

    context 'with the files of a working copy' do
      before { dir.join('config').mkpath }

      it { is_expected.to be false }
    end

    context 'with the mark the build writes' do
      before { dir.join('.image').write('') }

      it { is_expected.to be true }
    end
  end

  # The Docker image runs production. A working copy runs the name it was
  # started with, and both need a configuration for that name.
  describe '.verify_environment!' do
    subject(:verify!) do
      described_class.verify_environment!(dir.to_s, env, built)
    end

    let(:dir) { Pathname.new(Dir.mktmpdir) }
    let(:env) { 'production' }
    let(:built) { false }

    before { dir.join('environments').mkpath }

    after { dir.rmtree }

    context 'when the configuration knows the environment' do
      before { dir.join('environments', "#{env}.rb").write('') }

      it 'passes it' do
        expect { verify! }.not_to raise_error
      end
    end

    context 'when the configuration does not know the environment' do
      it 'stops the application' do
        expect { verify! }.to raise_error(
          described_class::Invalid,
          'no configuration for RAILS_ENV=production',
        )
      end
    end

    # The Docker image is built for one environment and runs that one. The name
    # it is started with does not change that, and a configuration file for that
    # name does not either.
    context 'with a Docker image' do
      let(:built) { true }

      before { dir.join('environments', "#{env}.rb").write('') }

      context 'when it is started as production' do
        it 'passes it' do
          expect { verify! }.not_to raise_error
        end
      end

      context 'when it is started as another name' do
        let(:env) { 'development' }

        it 'stops the application' do
          expect { verify! }.to raise_error(
            described_class::Invalid,
            'the Docker image runs production, not development',
          )
        end
      end
    end
  end
end
