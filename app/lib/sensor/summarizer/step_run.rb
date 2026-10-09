module Sensor
  class Summarizer
    # A step of the daily build on the days of a chunk (see Summary::Steps).
    # It starts its InfluxDB queries in a thread at once, so they overlap
    # with the build of the values, and it writes its result in the
    # transaction of the build.
    class StepRun
      # `shared` is what the steps of a chunk share (see Summary::Steps.shared)
      def initialize(step_class, dates, shared = {})
        @step = step_class.new(dates, **shared)
        @dates = dates
        @future = Concurrent::Future.execute { @step.call }
      end

      # Waits for the queries, outside the transaction
      def result
        @result ||= @future.value!
      end

      # Each day of the step gets the current version of the step, also
      # without a record of it. A day without the mark waits for the step
      # forever.
      def persist
        @step.persist(result)
        Summary.mark_step(@step.class, @dates)
      end
    end
  end
end
