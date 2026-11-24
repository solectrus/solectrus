module McpServer
  module Tools
    # The single charges of the cars (ChargingSession), which get_car_costs
    # only ever returns added up. A question about one charge ("where did I
    # charge in October?"), or a check before an entry, needs the charges
    # themselves. A charge over midnight, which the detection cuts into one
    # session for each day, comes as one charge, like in the list of the
    # browser. A dismissed proposal stays out, like there.
    #
    # The address and the position tell where a person was, so they come only
    # while the admin allows locations (see McpServer::Sensors).
    class ChargingSessions < Base
      tool_name 'get_charging_sessions'
      title 'Get the charges of the cars'
      description <<~TEXT.strip
        The single charges of the electric cars, newest first: at the wallbox
        (measured) and away from it (entered). get_car_costs only adds them up.

        `state`: `car` and `guest` count, `unassigned` is a wallbox charge
        without a car yet, and `proposal` is a charge away from the wallbox
        that SOLECTRUS found from the state of charge and nobody confirmed, so
        it does not count yet. `origin` says who wrote it last: `detection`,
        `user` (the admin) or `mcp` (an AI agent).

        `total_count` says how many matched, also beyond `limit`. A field
        without a value is left out.
      TEXT
      input_schema(
        properties: {
          from: {
            type: 'string',
            format: 'date',
            description: 'Only charges that start on or after this ISO 8601 date.',
          },
          to: {
            type: 'string',
            format: 'date',
            description: 'Only charges that start on or before this ISO 8601 date.',
          },
          car: {
            type: 'integer',
            minimum: 1,
            maximum: Sensor::Cars::MAX,
            description: 'Only the charges of this car, by its number in get_system_info.',
          },
          kind: {
            type: 'string',
            enum: ChargingSession.kinds.keys,
            description: '"wallbox" or "offsite" (away from the wallbox). Omit for both.',
          },
          limit: {
            type: 'integer',
            minimum: 1,
            maximum: CashFlows::MAX_ENTRIES,
            default: CashFlows::DEFAULT_LIMIT,
            description: 'Max charges returned.',
          },
        },
      )
      read_only idempotent: true

      def self.available? = Car.configured.any?

      def self.perform(from: nil, to: nil, limit: CashFlows::DEFAULT_LIMIT, **filters)
        first_day = parse_date(from, 'from')
        last_day = parse_date(to, 'to')
        reject_inverted_range(first_day, last_day)

        charges = filtered(first_day, last_day, **filters.slice(:car, :kind)).joined
        capped = limit.to_i.clamp(1, CashFlows::MAX_ENTRIES)

        {
          currency: Rails.configuration.x.currency,
          total_count: charges.count,
          charges: charges.order(started_at: :desc, id: :desc).limit(capped).map { serialize(it) },
        }
      end

      def self.filtered(first_day, last_day, car: nil, kind: nil)
        scope = ChargingSession.where(dismissed: false)
        scope = scope.where(started_at: first_day.beginning_of_day..) if first_day
        scope = scope.where(started_at: ..last_day.end_of_day) if last_day
        scope = scope.where(car_id: car) if car
        scope = scope.where(kind:) if kind
        scope
      end
      private_class_method :filtered

      # A charge as get_charging_sessions lists it, which set_offsite_session
      # answers with as well
      def self.serialize(session)
        {
          id: session.id,
          kind: session.kind,
          state: state(session),
          car: session.car_id,
          started_at: session.started_at&.iso8601,
          ended_at: session.ended_at&.iso8601,
          kwh: session.kwh&.to_f,
          cost: Precision.round(session.cost, :money),
          soc_from: session.soc_from&.to_f,
          soc_to: session.soc_to&.to_f,
          power_type: session.power_type,
          provider: session.provider,
          evse_id: session.evse_id,
          note: session.note,
          origin: session.origin,
          **location(session),
        }.compact
      end

      # How a charge counts (see ChargingSession): an offsite session counts
      # once the admin or an agent entered or accepted it
      def self.state(session)
        if session.offsite? then session.assigned_manually? ? 'car' : 'proposal'
        elsif session.car_id then 'car'
        elsif session.guest? then 'guest'
        else 'unassigned'
        end
      end
      private_class_method :state

      def self.location(session)
        return {} unless McpServer::Sensors.locations?

        { address: session.address, latitude: session.latitude, longitude: session.longitude }
      end
      private_class_method :location
    end
  end
end
