# Whether a wallbox session still goes on. The detection writes the end of
# the latest bucket with power, so a running charge gets an end and a state
# of charge at the end that change with each build. The table does not know
# whether the charge goes on, so .mark_ongoing sets it when a page reads the
# sessions, like PlaceVisit.mark_ongoing.
module ChargingSession::Ongoing
  extend ActiveSupport::Concern

  included do
    attribute :ongoing, :boolean, default: false
  end

  class_methods do
    # Marks the latest wallbox session among the joined `sessions` as ongoing
    # while it goes on: the detection saw it up to its latest build of today,
    # and the wallbox charges now. A gap of the detection does not end a
    # session (see ChargingSession::Detection::Periods), so the session can
    # end up to GAP before the build. The power comes from InfluxDB, like in
    # the live view (see Car::Live), so it asks only when the latest session
    # is among them.
    def mark_ongoing(sessions)
      latest = unscoped.wallbox.maximum(:ended_at)
      session = latest && sessions.find { it.wallbox? && it.ended_at == latest }
      return unless session

      built_at = Summary.where(date: Date.current).pick(:updated_at)
      return unless built_at && latest >= built_at - ChargingSession::Detection::Periods::GAP

      session.ongoing = Sensor::Query::Latest.new([:wallbox_power]).call.wallbox_power.to_f.positive?
    end
  end
end
