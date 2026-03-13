Rails.configuration.x.git.commit_version =
  ENV.fetch('COMMIT_VERSION') do
    version_prefix_file = Rails.root.join('VERSION_PREFIX')
    if version_prefix_file.exist?
      prefix = version_prefix_file.read.strip
      count = `git rev-list --count main..HEAD`.chomp
      hash = `git rev-parse --short=7 HEAD`.chomp
      "#{prefix}-#{count}-g#{hash}"
    else
      `git describe --always --abbrev=7`.chomp
    end
  end

Rails.configuration.x.git.commit_time =
  Time.zone.parse(ENV.fetch('COMMIT_TIME') { `git show -s --format=%cI` })

Rails.configuration.x.git.home = 'https://github.com/solectrus/solectrus'

Rails.configuration.x.app_name = 'SOLECTRUS'
