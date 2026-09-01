describe Installation do
  # The mount table of a real container, shortened. Docker mounts a handful of
  # its own, all outside the application.
  let(:docker_mounts) do
    %w[
      /proc
      /dev
      /sys
      /etc/resolv.conf
      /etc/hostname
      /etc/hosts
    ]
  end

  describe '.foreign_mounts' do
    it 'passes an installation that mounts nothing' do
      expect(described_class.foreign_mounts('/rails', docker_mounts)).to be_empty
    end

    it 'names a file mounted into the code' do
      mounts = docker_mounts + ['/rails/config/initializers/zz.rb']

      expect(described_class.foreign_mounts('/rails', mounts)).to eq(
        ['/rails/config/initializers/zz.rb'],
      )
    end

    # No directory below the root is exempt.
    it 'names a mount into a directory the application writes to' do
      mounts = docker_mounts + %w[/rails/tmp/cache /rails/log]

      expect(described_class.foreign_mounts('/rails', mounts)).to eq(
        %w[/rails/tmp/cache /rails/log],
      )
    end

    it 'names a mount over the root itself' do
      mounts = docker_mounts + ['/rails']

      expect(described_class.foreign_mounts('/rails', mounts)).to eq(['/rails'])
    end

    it 'ignores a path that only starts like the root' do
      expect(
        described_class.foreign_mounts('/rails', ['/rails-other/app/x.rb']),
      ).to be_empty
    end
  end
end
