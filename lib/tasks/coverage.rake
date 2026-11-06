namespace :coverage do
  desc 'Merge coverage results from multiple test runs'

  task :merge do # rubocop:disable Rails/RakeEnvironment
    require 'simplecov'

    # Find all coverage result files (uploaded as coverage/ folders)
    coverage_files = Dir['coverage-parts/**/.resultset.json']

    if coverage_files.empty?
      abort 'No coverage files found in coverage-parts/'
    end

    puts "Merging #{coverage_files.size} coverage files..."
    coverage_files.each { |f| puts "  - #{f}" }

    # Formatter, groups and filters come from .simplecov. Writes the merged
    # coverage/.resultset.json that CI uploads to Qlty.
    SimpleCov.collate(coverage_files)

    puts 'Coverage merged successfully!'
  end

  # A single spec run covers only a part of the app, so the minimum cannot
  # live in .simplecov. This runs after the merge of all runs, which writes
  # the merged figure to coverage/.last_run.json.
  #
  # Branches have a floor instead of 100 %: a part of the missing ones are
  # defensive guards and UI variants that a spec would only repeat. Raise the
  # floor when the figure goes up.
  desc 'Fail unless the merged coverage reaches its minimum'
  task :check do # rubocop:disable Rails/RakeEnvironment
    require 'json'

    minimum = { 'line' => 100, 'branch' => 90 }

    path = 'coverage/.last_run.json'
    abort "#{path} not found. Run the specs first." unless File.exist?(path)

    result = JSON.parse(File.read(path))['result']
    too_low = minimum.reject { |criterion, min| result[criterion].to_f >= min }

    minimum.each do |criterion, min|
      value = result[criterion] ? "#{result[criterion]} %" : 'missing'
      puts "#{criterion.capitalize} coverage: #{value} (minimum #{min} %)"
    end

    if too_low.any?
      abort "Coverage below minimum: #{too_low.keys.join(', ')}. " \
            'coverage/index.html shows the lines and branches that no spec runs.'
    end
  end
end
