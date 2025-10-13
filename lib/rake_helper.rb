module RakeHelper
  # Rake tasks that should skip certain initialization steps
  SKIP_INIT_TASKS = %w[assets:precompile db:create db:migrate db:prepare].freeze
  private_constant :SKIP_INIT_TASKS

  # Check if any of the specified Rake tasks are currently running
  def rake_task_running?(*tasks)
    return false unless defined?(Rake)

    tasks.any? { |task| Rake.application.top_level_tasks.include?(task) }
  end

  # Check if we should skip initialization
  # This includes console and certain rake tasks (only in development)
  def skip_initialization?
    # Check for rake tasks that should skip (including in test environment)
    return true if rake_task_running?(*SKIP_INIT_TASKS)

    # Skip only for console in development (not for runner, not in production)
    return true if Rails.env.development? && defined?(Rails::Console)

    # In production, always run initialization
    # In test environment, always run initialization (needed for tests)
    false
  end
end
