describe AppDigest do
  describe '.current' do
    # The test environment is a local one, and a local environment has no
    # digest. The instance below drives the calculation itself.
    it 'is nothing in a local environment' do
      expect(described_class.current).to be_nil
    end
  end

  describe '#digest_of' do
    let(:root) { Pathname.new(Dir.mktmpdir) }

    before do
      write 'app/models/user.rb', 'class User; end'
      write 'config/boot.rb', 'BOOT = true'
    end

    after { root.rmtree }

    def write(path, content)
      file = root.join(path)
      file.dirname.mkpath
      file.write(content)
    end

    def digest
      described_class.instance.digest_of(root)
    end

    it 'is a short hexadecimal string' do
      expect(digest).to match(/\A[0-9a-f]{8}\z/)
    end

    it 'is the same for the same files' do
      expect(digest).to eq(described_class.instance.digest_of(root))
    end

    it 'changes when a file changes' do
      before_change = digest
      write 'app/models/user.rb', 'class User; def admin? = true; end'

      expect(digest).not_to eq(before_change)
    end

    it 'changes when a file arrives' do
      before_change = digest
      write 'lib/patch.rb', 'PATCH = true'

      expect(digest).not_to eq(before_change)
    end

    # The path is hashed with the content, so a file that keeps its content
    # but changes its place is a change too.
    it 'changes when a file moves' do
      before_change = digest
      root.join('app/models/user.rb').rename(root.join('app/models/admin.rb'))

      expect(digest).not_to eq(before_change)
    end

    # Only what a file holds counts. The CI builds one image per
    # architecture, and the same file carries a different time in each of
    # them.
    it 'is the same when only the time of a file changes' do
      before_change = digest
      file = root.join('app/models/user.rb')
      file.utime(file.atime, file.mtime + 60)

      expect(digest).to eq(before_change)
    end

    it 'leaves out what the application writes while it runs' do
      before_change = digest
      write 'log/production.log', 'started'

      expect(digest).to eq(before_change)
    end

    it 'counts hidden entries' do
      before_change = digest
      write '.bundle/config', 'BUNDLE_PATH: vendor'

      expect(digest).not_to eq(before_change)
    end

    it 'counts a hidden file below a directory it reads' do
      before_change = digest
      write 'config/.env', 'SECRET=1'

      expect(digest).not_to eq(before_change)
    end
  end
end
