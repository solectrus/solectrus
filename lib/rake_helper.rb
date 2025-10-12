module RakeHelper
  # Rake tasks that should skip certain initialization steps
  SKIP_INIT_TASKS = %w[assets:precompile db:create db:migrate db:prepare].freeze
  private_constant :SKIP_INIT_TASKS

  # Check if any of the specified Rake tasks are currently running
  def rake_task_running?(*tasks)
    return false unless defined?(Rake)

    tasks.any? { |task| Rake.application.top_level_tasks.include?(task) }
  end

  # Check if any of the initialization-skipping tasks are running
  def skip_init_rake_task_running?
    rake_task_running?(*SKIP_INIT_TASKS)
  end
end
