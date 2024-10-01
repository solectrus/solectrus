require 'singleton'
require 'concurrent'

class BackgroundTask
  include Singleton

  def initialize
    @task = nil
  end

  def start
    return if @task&.running?

    @task =
      Concurrent::ThreadPoolExecutor.new(
        min_threads: 1,
        max_threads: 1,
        max_queue: 0,
      )

    start_time = Time.current

    @task.post do
      loop do
        BackgroundCalculationJob.perform_later(start_time)

        sleep(3)
      end
    end

    Rails.logger.info('Background task STARTED')
  end

  def stop
    return unless @task && !@task.shutdown?

    @task.shutdown
    @task = nil

    Rails.logger.info('Background task STOPPED')
  end
end
