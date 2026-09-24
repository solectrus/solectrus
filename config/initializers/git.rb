# An initializer cannot autoload from lib, which is reloadable.
require_relative '../../lib/build_info'

# The Docker image names its commit in a file, not in the environment, which can
# hold the values of an older image (see BuildInfo). A working copy has no such
# file and asks git.
commit = BuildInfo.read

Rails.configuration.x.git.commit_version =
  commit.fetch('COMMIT_VERSION') do
    version_prefix_file = Rails.root.join('VERSION_PREFIX')
    if version_prefix_file.exist?
      prefix = version_prefix_file.read.strip
      count = `git rev-list --count main..HEAD`.chomp
      hash = `git rev-parse --short=7 HEAD`.chomp
      "#{prefix}-#{count}-g#{hash}"
    else
      `git describe --always --abbrev=7`.chomp.presence || 'unknown'
    end
  end

Rails.configuration.x.git.commit_time =
  Time.zone.parse(commit.fetch('COMMIT_TIME') { `git show -s --format=%cI` })

Rails.configuration.x.git.home = 'https://github.com/solectrus/solectrus'
