Rails.configuration.x.git.home        = 'https://github.com/solectrus/solectrus'
Rails.configuration.x.git.commit_sha  = ENV.fetch('COMMIT_SHA') { `git rev-parse HEAD` }
Rails.configuration.x.git.commit_time = Time.zone.parse(
  ENV.fetch('COMMIT_TIME') { `git show -s --format=%cD` }
)
