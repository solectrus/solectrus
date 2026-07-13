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
end
