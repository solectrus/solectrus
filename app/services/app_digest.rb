# A digest of every file this installation can load - the code, the
# configuration, the scripts that start it and the assets it serves.
#
# Read when the application first names itself to the update server, and kept
# for the rest of the process. Not at boot: a task boots the application too,
# and a task names itself to nobody.
#
# Every installation of a release reads the same files and names the same
# digest. That is what makes one that differs worth a look.
class AppDigest
  include Singleton

  # Directories the Docker image does not hold: what the application writes
  # while it runs, and what only a working copy carries. Everything else counts,
  # because everything else can be loaded.
  SKIPPED = %w[.git coverage log node_modules spec tmp].freeze
  private_constant :SKIPPED

  # How much of the digest is kept. Enough to tell two installations apart,
  # and it names no file of either.
  LENGTH = 8
  private_constant :LENGTH

  class << self
    delegate :current, to: :instance
  end

  # The digest of this installation, or nothing.
  #
  # The digest belongs to the Docker image. Development and test ask no update
  # server (see UpdateCheck.skip_http?), and they write into their own
  # directories while they run, so a file can disappear there between the
  # listing and the read.
  #
  # Reading Rails.env here is safe because the Docker image runs production and
  # stops at boot under any other name (see DockerImage.verify_environment!).
  def current
    return if Rails.env.local?

    @current ||= digest_of(Rails.root)
  end

  # The path of a file is hashed with its size, the time of its last change and
  # its content. A file that only moves changes the digest, and so does one
  # that is put back the way it was found.
  def digest_of(root)
    digest = Digest::SHA256.new

    files(root).each do |file|
      stat = file.lstat

      digest << file.relative_path_from(root).to_s
      digest << stat.size.to_s
      digest << stat.mtime.to_i.to_s
      digest << file.binread
    end

    digest.hexdigest[0, LENGTH]
  end

  private

  def files(root)
    root
      .children
      .flat_map { |entry| entries_of(entry) }
      .select(&:file?)
      .sort
  end

  def entries_of(entry)
    return [] if SKIPPED.include?(entry.basename.to_s)

    entry.directory? ? entry.glob('**/*', File::FNM_DOTMATCH) : entry
  end
end
