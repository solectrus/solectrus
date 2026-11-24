module McpServer
  module Tools
    # Adds or changes one entry of the electricity tariff or the feed-in
    # compensation, as the admin does in the settings. A tariff has one entry
    # per start date, so the start date finds the entry to change, and a client
    # that reads the same bill twice changes nothing the second time.
    #
    # The tool deletes nothing, and the rules of a price stay in Price: the
    # tool only reports what the model rejects.
    class SetPrice < Base
      extend Recording

      # The arguments that a call without `id` needs, because they find or add
      # the entry (see Recording#require_without_id)
      NEEDED = %i[name starts_at].freeze
      private_constant :NEEDED

      tool_name 'set_price'
      title 'Add or change an electricity or feed-in price'
      description <<~TEXT.strip
        Records a price of the electricity tariff (grid import) or of the
        feed-in compensation (export), for example from a bill or a contract.
        A tariff has one entry per `starts_at` date, valid from that date until
        the next entry. An entry with the same `name` and `starts_at` is
        changed, otherwise a new one is added.

        A new entry needs `value`. When an entry changes, an argument that is
        left out keeps its value, and null clears `base_fee_per_month` or
        `note`. Call get_prices first to see the existing entries.

        Every rate is per kWh in the system currency (see get_system_info). Only
        the electricity tariff can carry a monthly base fee for the grid
        connection.
      TEXT
      input_schema(
        properties: {
          name: {
            type: 'string',
            enum: Price.names.keys,
            description: '"electricity" for the grid import price, "feed_in" for the feed-in compensation.',
          },
          starts_at: {
            type: 'string',
            format: 'date',
            description: 'ISO 8601 date from which the price is valid, e.g. "2026-01-01".',
          },
          value: {
            type: 'number',
            minimum: 0,
            description: 'The rate per kWh, e.g. 0.3125. Required for a new entry.',
          },
          base_fee_per_month: {
            type: %w[number null],
            minimum: 0,
            description: 'The monthly base fee of the electricity tariff. null removes it.',
          },
          note: {
            type: %w[string null],
            description: 'A short note, e.g. the name of the tariff. null removes it.',
          },
          id: Recording.id_property(*NEEDED),
        },
      )
      writes idempotent: true, destructive: true

      # What the tool records, for the instructions of the server
      def self.records = 'a price of the tariffs'

      def self.available? = write_enabled?

      # The arguments and the attributes of Price they set
      ARGUMENTS = { value: :amount_per_kwh, base_fee_per_month: :amount_per_month, note: :note }.freeze
      private_constant :ARGUMENTS

      def self.perform(id: nil, **args)
        require_without_id(id, args, NEEDED)
        name = args[:name]
        raise ArgumentError, "Invalid name #{name.inspect}: use \"electricity\" or \"feed_in\"." if name && !Price.names.key?(name)

        date = iso_date(args[:starts_at], 'starts_at') if args.key?(:starts_at)
        price = id ? own_entry(Price.all, id) : Price.find_or_initialize_by(name:, starts_at: date)
        previous = serialize(price) if price.persisted?
        price.assign_attributes(**{ name:, starts_at: date }.compact, **attributes_from(args, ARGUMENTS))
        result = save_entry(price, ARGUMENTS)

        { result:, entry: serialize(price), previous: (previous if result == 'updated') }.compact
      end

      # A price as get_prices lists it, with the tariff that it belongs to
      def self.serialize(price) = { name: price.name, **Prices.serialize(price) }
      private_class_method :serialize
    end
  end
end
