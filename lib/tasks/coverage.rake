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
  desc 'Fail unless the merged line coverage is 100 %'
  task :check do # rubocop:disable Rails/RakeEnvironment
    require 'json'

    path = 'coverage/.last_run.json'
    abort "#{path} not found. Run the specs first." unless File.exist?(path)

    line = JSON.parse(File.read(path)).dig('result', 'line')
    if line < 100
      abort "Line coverage is #{line} %, but must be 100 %. " \
            'coverage/index.html lists the lines that no spec runs.'
    end

    puts "Line coverage: #{line} %"
  end
end
