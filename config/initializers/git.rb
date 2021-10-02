Rails.configuration.x.git.commit_version =
  ENV.fetch('COMMIT_VERSION') { `git describe`.chomp }

Rails.configuration.x.git.commit_time =
  Time.zone.parse(ENV.fetch('COMMIT_TIME') { `git show -s --format=%cI` })

Rails.configuration.x.git.home = 'https://github.com/solectrus/solectrus'
