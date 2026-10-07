# A change of a price gives a new cost to the wallbox sessions on the days of
# that price (see Price), of each origin. The new cost comes from the stored
# energy, so the detection does not read InfluxDB again.
module ChargingSession::Repricing
  extend ActiveSupport::Concern

  class_methods do
    # Prices the wallbox sessions on the given dates again, with the prices of
    # their day (see ChargingSession::Cost). The end of the dates can be open.
    def reprice(dates)
      cost = ChargingSession::Cost.new
      rows =
        wallbox
          .where(started_at: dates.begin.beginning_of_day..dates.end&.end_of_day)
          .pluck(:id, :origin, :started_at, :ended_at, :kwh, :kwh_grid)
          .map do |id, origin, started_at, ended_at, kwh, kwh_grid|
            session_cost, cost_grid = cost.call(started_at.in_time_zone.to_date, kwh.to_f, kwh_grid&.to_f)
            # The upsert updates the cost alone, but the new row must pass the
            # checks of the table
            { id:, origin:, started_at:, ended_at:, kind: 'wallbox', kwh:, cost: session_cost, cost_grid: }
          end
      return if rows.empty?

      # On the id and not on the index of the detection, which holds only
      # the rows of the detection
      upsert_all(rows, unique_by: :id, update_only: %i[cost cost_grid])
    end
  end
end
