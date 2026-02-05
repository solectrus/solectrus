namespace :coverage do
  desc 'Merge coverage results from multiple test runs'

  task :merge do # rubocop:disable Rails/RakeEnvironment
    # Prevent .simplecov from auto-starting coverage tracking
    ENV['SIMPLECOV_COLLATE_ONLY'] = '1'
    require 'simplecov'
    require 'simplecov_json_formatter'

    # Find all coverage result files (uploaded as coverage/ folders)
    coverage_files = Dir['coverage-parts/**/.resultset.json']

    if coverage_files.empty?
      abort 'No coverage files found in coverage-parts/'
    end

    puts "Merging #{coverage_files.size} coverage files..."
    coverage_files.each { |f| puts "  - #{f}" }

    SimpleCov.collate(coverage_files) do
      formatter SimpleCov::Formatter::MultiFormatter.new(
        [
          SimpleCov::Formatter::JSONFormatter,
          SimpleCov::Formatter::HTMLFormatter,
        ],
      )
    end

    puts 'Coverage merged successfully!'
  end
end
