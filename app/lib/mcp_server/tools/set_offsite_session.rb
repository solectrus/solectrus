module McpServer
  module Tools
    # Enters a charge of a car away from the wallbox, as the admin does in the
    # form of a charging session. The time of the charge finds the session
    # (see ChargingSession.for_charge): a session in the same time is the same
    # charge, and a proposal of the build gets the values of the receipt and
    # counts from then on. The tool deletes nothing.
    #
    # The address goes through the same lookup as in the form. A position
    # tells where a person was, so the answer gives the address, the found
    # address and the position only while the admin allows locations (see
    # McpServer::Sensors).
    class SetOffsiteSession < Base
      extend Recording

      # The arguments that a call without `id` needs, because they find or add
      # the entry (see Recording#require_without_id)
      NEEDED = %i[car started_at].freeze
      private_constant :NEEDED

      tool_name 'set_offsite_session'
      title 'Enter a charge of a car away from the wallbox'
      description <<~TEXT.strip
        Records a charge of an electric car at a public station or another
        wallbox, for example from the receipt of a charging provider. Not for
        the own wallbox: those charges come from the measurements.

        The car and the time find the charge. A car charges at one station at
        a time, so a charge in the same time is changed. A proposal that
        SOLECTRUS found from the state of charge of the car, with up to an
        hour around it, gets the values and counts from then on: the answer
        is `accepted`. Otherwise a new charge is added.

        `kwh` and `cost` are required for a new charge: the energy that the
        receipt bills and its total cost in the system currency (see
        get_system_info). When a charge changes, an argument that is left out
        keeps its value, and null clears an optional one.

        If `found_address` names another town than the receipt, tell the user.
      TEXT
      input_schema(
        properties: {
          car: {
            type: 'integer',
            minimum: 1,
            maximum: Sensor::Cars::MAX,
            description: 'The number of the car, as get_system_info lists it.',
          },
          started_at: {
            type: 'string',
            format: 'date-time',
            description: 'Start of the charge, ISO 8601 with offset, e.g. "2026-03-15T14:05:00+01:00".',
          },
          ended_at: {
            type: 'string',
            format: 'date-time',
            description: 'End of the charge, ISO 8601 with offset.',
          },
          kwh: {
            type: 'number',
            exclusiveMinimum: 0,
            description: 'The billed energy in kWh.',
          },
          cost: {
            type: 'number',
            minimum: 0,
            description: 'The total cost of the charge.',
          },
          power_type: {
            type: %w[string null],
            enum: [*ChargingSession.power_types.keys, nil],
            description: '"ac" or "dc".',
          },
          provider: {
            type: %w[string null],
            description: 'The charging provider or the tariff, e.g. the name on the receipt.',
          },
          evse_id: {
            type: %w[string null],
            description: 'The ID of the charge point, e.g. "DE*ABC*E123456".',
          },
          address: {
            type: %w[string null],
            description: 'The address of the station, e.g. "Main Street 15, 12345 Town".',
          },
          note: Recording::NOTE_PROPERTY,
          id: Recording.id_property(*NEEDED),
        },
      )
      writes idempotent: true, destructive: true

      # What the tool records, for the instructions of the server
      def self.records = 'a charge of a car away from the wallbox'

      def self.available? = write_enabled? && Car.configured.any?

      # The arguments and the attributes of ChargingSession they set
      ARGUMENTS = {
        started_at: :started_at,
        ended_at: :ended_at,
        kwh: :kwh,
        cost: :cost,
        power_type: :power_type,
        provider: :provider,
        evse_id: :evse_id,
        address: :address,
        note: :note,
      }.freeze
      private_constant :ARGUMENTS

      def self.perform(id: nil, **args)
        require_without_id(id, args, NEEDED)
        car = car_of(args)
        times = times_of(args)

        session = id ? own_entry(ChargingSession.offsite, id) : ChargingSession.for_charge(car:, **times)
        proposal = session.proposal?
        previous = ChargingSessions.serialize(session) if session.persisted?

        # The car too only after `previous`, so the answer shows the move
        session.assign_attributes({ car: }.compact.merge(attributes_from(args.merge(times), ARGUMENTS)))
        result = save_entry(session, ARGUMENTS) { ChargingSession::AddressLookup.new(session).save }
        result = 'accepted' if proposal && result == 'updated'

        { result:, entry: ChargingSessions.serialize(session), previous: (previous if result.in?(%w[updated accepted])) }.compact
      end

      # The times that the call gives
      def self.times_of(args)
        %i[started_at ended_at].filter_map { [it, iso_time(args[it], it.to_s)] if args[it] }.to_h
      end
      private_class_method :times_of
    end
  end
end
