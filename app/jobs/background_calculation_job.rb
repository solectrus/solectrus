class BackgroundCalculationJob < ApplicationJob
  queue_as :default

  def perform(start_time)
    ActiveRecord::Base.connection_pool.with_connection do
      perform_calculations(start_time)
    end
  end

  private

  def perform_calculations(start_time)
    Price.last

    Turbo::StreamsChannel.broadcast_update_to(
      'progress',
      target: 'progress-bar',
      partial: 'progress/show',
      locals: {
        progress: (Time.current - start_time).to_i,
      },
    )
  end
end
