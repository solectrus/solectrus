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

        `current` is always derived from the FULL history, independent of
        `limit` — which caps only the returned history, so an unbounded price
        history is never dumped in full unless asked for.

        All values are per kWh in the system currency (see get_system_info).
      TEXT
      input_schema(
        properties: {
          date: {
            type: 'string',
            description:
              'ISO 8601 date selecting the effective price, e.g. "2026-06-21". Defaults to today.',
          },
          sort: {
            type: 'string',
            enum: %w[date value],
            description: 'Sort the history by "date" (default) or "value".',
          },
          order: {
            type: 'string',
            enum: %w[desc asc],
            description: '"desc" = newest/highest first (default), "asc" = oldest/lowest first.',
          },
          limit: {
            type: 'integer',
            description: 'Max history entries per price type (1-100). Defaults to 10.',
          },
        },
      )
      read_only idempotent: false

      def self.call(date: nil, sort: 'date', order: 'desc', limit: 10, **)
        on = date.present? ? Date.parse(date) : Date.current
        currency = Rails.configuration.x.currency
        capped = limit.to_i.clamp(1, 100)

        prices =
          Price.names.keys.map do |name|
            {
              name:,
              unit: "#{currency}/kWh",
              current: Precision.round(Price.at(name:, date: on), :money_per_kwh),
              history: history_for(name, sort:, order:, limit: capped),
            }
          end

        json_response(date: on.iso8601, currency:, sort:, order:, limit: capped, prices:)
      rescue ArgumentError => e
        error_response("Invalid date: #{e.message}")
      end

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
