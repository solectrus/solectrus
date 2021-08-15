tag_or_branch =
  ENV.fetch('TAG_OR_BRANCH') do
    `git describe --tags --exact-match 2> /dev/null ||
     git symbolic-ref -q --short HEAD ||
     git rev-parse --short HEAD`.chomp
  end

commit_sha = (ENV.fetch('COMMIT_SHA') { `git rev-parse HEAD` }).first(7)

Rails.configuration.x.git.version =
  if tag_or_branch.match?(/v\d+\.\d+\.\d+/)
    tag_or_branch
  else
    "#{tag_or_branch}-#{commit_sha}"
  end

Rails.configuration.x.git.commit_time =
  Time.zone.parse(ENV.fetch('COMMIT_TIME') { `git show -s --format=%cI` })

Rails.configuration.x.git.home = 'https://github.com/solectrus/solectrus'
