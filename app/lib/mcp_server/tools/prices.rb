module McpServer
  module Tools
    # Electricity tariff and feed-in compensation, as configured in SOLECTRUS.
    # Prices are time-dependent (each entry is valid from its starts_at date),
    # so both the value effective on a given date and the full change history
    # are returned.
    class Prices < Base
      tool_name 'get_prices'
      title 'Get electricity and feed-in prices'
      description <<~TEXT.strip
        The configured electricity tariff (grid import price) and feed-in
        compensation (export price). Prices are time-dependent: each entry is
        valid from its `starts_at` date onwards. Returns, per price type, the
        value effective on `date` plus its change history.

        `effective` is the price valid ON `date` — a past `date` yields a
        historical tariff, not today's, so read it together with the `date`
        echoed at the top level. It is always derived from the FULL history,
        independent of `limit`, which caps only the returned history so an
        unbounded one is never dumped unless asked for.

        All values are per kWh in the system currency (see get_system_info).
      TEXT
      input_schema(
        properties: {
          date: {
            type: 'string',
            format: 'date',
            description:
              'ISO 8601 date selecting the effective price, e.g. "2026-06-21". Defaults to today.',
          },
          sort: {
            type: 'string',
            enum: %w[date value],
            default: 'date',
            description: 'Sort the history by "date" or "value".',
          },
          order: {
            type: 'string',
            enum: %w[desc asc],
            default: 'desc',
            description: '"desc" = newest/highest first, "asc" = oldest/lowest first.',
          },
          limit: {
            type: 'integer',
            minimum: 1,
            maximum: 100,
            default: 10,
            description: 'Max history entries per price type.',
          },
        },
      )
      read_only idempotent: false

      def self.perform(date: nil, sort: 'date', order: 'desc', limit: 10, **)
        on = parse_date(date)
        currency = Rails.configuration.x.currency
        capped = limit.to_i.clamp(1, 100)

        prices =
          Price.names.keys.map do |name|
            {
              name:,
              unit: "#{currency}/kWh",
              # Named for what it is - the price valid on `date` - rather than
              # "current", which claimed today's tariff even when `date` asked
              # about 2023.
              effective: Precision.round(Price.at(name:, date: on), :money_per_kwh),
              history: history_for(name, sort:, order:, limit: capped),
            }
          end

        { date: on.iso8601, currency:, sort:, order:, limit: capped, prices: }
      end

      # Re-raised with the "Invalid date" lead, since Date.parse's own message
      # ("invalid date") says nothing about which argument was wrong.
      def self.parse_date(date)
        return Date.current if date.blank?

        Date.parse(date)
      rescue ArgumentError => e
        raise ArgumentError, "Invalid date: #{e.message}"
      end
      private_class_method :parse_date

      def self.history_for(name, sort:, order:, limit:)
        direction = order.to_s == 'asc' ? :asc : :desc
        # Sort by value with starts_at as a stable tie-breaker; otherwise by date.
        clause =
          sort.to_s == 'value' ? { value: direction, starts_at: :desc } : { starts_at: direction }

        Price.where(name:).order(clause).limit(limit).map do |price|
          {
            starts_at: price.starts_at.iso8601,
            value: Precision.round(price.value, :money_per_kwh),
            note: price.note,
          }
        end
      end
      private_class_method :history_for
    end
  end
end
