commit_version =
  ENV.fetch('COMMIT_VERSION') { `git describe --always --abbrev=7`.chomp }
commit_branch =
  ENV.fetch('COMMIT_BRANCH') { `git rev-parse --abbrev-ref HEAD`.chomp }

Rails.configuration.x.git.commit_version =
  if commit_branch.present? && %w[main develop].exclude?(commit_branch)
    parts = commit_version.split('-')
    [commit_branch, parts.second, parts.third].compact.join('-')
  else
    commit_version
  end

Rails.configuration.x.git.commit_time =
  Time.zone.parse(ENV.fetch('COMMIT_TIME') { `git show -s --format=%cI` })

Rails.configuration.x.git.home = 'https://github.com/solectrus/solectrus'
