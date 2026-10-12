module Sensor
  module Chart
    module Concerns
      # The offsite sessions of the selected cars in a curve of a day on the
      # car page. An offsite session has no power curve, so the curves of its
      # car tell when it charged (see ChargingSession::OffsiteProfile). The
      # curve stacks them on the wallbox.
      module OffsiteSessions
        include SelectedCars

        # The buckets of InfluxDB and of the offsite sessions
        BUCKET = Sensor::Query::Helpers::Influx::DailyCurves::BUCKET
        private_constant :BUCKET

        private

        # Without wallbox data in InfluxDB, the offsite sessions get a grid of
        # their own
        def master_labels(items)
          labels = super
          labels.blank? && offsite_sessions.any? ? day_grid : labels
        end

        # The sum of a value of the offsite sessions in each bucket, from the
        # block, which gets a session and the energy (Wh) of a part of it. A
        # label is the end of its bucket, like the buckets of InfluxDB. A part
        # of the profile falls into one or two buckets and gives each its
        # share, so a session shorter than a bucket keeps its value.
        def offsite_sums(labels)
          return [] if labels.empty?

          start = (labels.first / 1000) - BUCKET.to_i
          sums = Array.new(labels.size, 0.0)
          ChargingSession::OffsiteProfile.new(offsite_sessions).by_session.each do |session, parts|
            parts.each { |from, to, energy| spread(sums, start, from, to, yield(session, energy)) }
          end
          sums
        end

        # The mean rate in each bucket (per hour) of the sums
        def per_hour(sums) = sums.map { it * 3600 / BUCKET }

        # Adds the value of a part of the profile to the buckets it falls
        # into. The first bucket starts at the epoch second `start`.
        def spread(sums, start, from, to, value)
          step = BUCKET.to_i

          (((from.to_i - start) / step)..((to.to_i - 1 - start) / step)).each do |index|
            next unless index.between?(0, sums.size - 1)

            bucket_from = start + (index * step)
            sums[index] += value * ([to.to_f, bucket_from + step].min - [from.to_f, bucket_from].max) / (to - from)
          end
        end

        # The buckets of the day up to now. Like in InfluxDB, the last bucket
        # ends with the day.
        def day_grid
          count = ((timeframe.ending - timeframe.beginning) / BUCKET).ceil
          (1..count).map { [timeframe.beginning + (it * BUCKET), timeframe.ending].min }.select { it <= Time.current }.map { timestamp_to_ms(it) }
        end

        # The offsite sessions of the selected cars that reach into the day.
        # The live view shows none. A session without an end belongs to its
        # day alone.
        def offsite_sessions
          @offsite_sessions ||=
            if timeframe.day?
              ChargingSession
                .offsite
                .effective
                .includes(:car)
                .where(car_id: cars.map(&:id))
                .where(started_at: ..timeframe.ending)
                .where('COALESCE(ended_at, started_at) >= ?', timeframe.beginning)
                .to_a
            else
              []
            end
        end
      end
    end
  end
end
