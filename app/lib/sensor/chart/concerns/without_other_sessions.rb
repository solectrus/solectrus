module Sensor
  module Chart
    module Concerns
      # A curve of a day on the car page without the wallbox sessions that
      # count for no selection (see #selected_session?): a session that is not
      # assigned, a session of another car, and a guest session, which counts
      # only for the guest and for "all" (see CarSelection#with_guest?). So a
      # day shows what the selection charged, like the charged energy beside it
      # (see Car::Report). A charge that the detection has not found yet stays.
      module WithoutOtherSessions
        include SelectedCars

        private

        # The values of the buckets in a session of others are 0
        def without_other_sessions(chart_data_item)
          return chart_data_item if other_windows.empty?

          labels = chart_data_item[:labels]
          data = chart_data_item[:data].each_with_index.map { |value, index| value && other_window?(labels[index]) ? 0 : value }
          chart_data_item.merge(data:)
        end

        # Whether the bucket of a label lies in a session of others. A label is
        # the end of its bucket, and a session starts and ends at the edges of
        # its buckets (see ChargingSession::Detection::Periods).
        def other_window?(label)
          other_windows.any? { |from, to| label > from && label <= to }
        end

        # [[from, to], ...] in milliseconds: the wallbox sessions of the day
        # that count for no selection. The live view has none.
        def other_windows
          @other_windows ||=
            if timeframe.day?
              ChargingSession
                .wallbox
                .where(started_at: timeframe.beginning..timeframe.ending)
                .pluck(:car_id, :guest, :started_at, :ended_at)
                .reject { |car_id, guest, _, _| selected_session?(car_id, guest) }
                .map { |_, _, from, to| [timestamp_to_ms(from), timestamp_to_ms(to)] }
            else
              []
            end
        end

        # Whether a wallbox session counts for the selection: a session of a
        # selected car, and a guest session for the guest and for "all"
        def selected_session?(car_id, guest)
          cars.any? { it.id == car_id } || (guest? && car_id.nil? && guest)
        end
      end
    end
  end
end
