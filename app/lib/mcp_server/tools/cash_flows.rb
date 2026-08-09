module McpServer
  module Tools
    # The manually kept cash flow register (CashFlow): the individual entries
    # get_amortization only ever returns aggregated. A question about one of
    # them ("what did the battery cost?", "which repairs were there?") has no
    # answer in the figures alone, so the register itself is readable here.
    class CashFlows < Base
      tool_name 'get_cash_flows'
      title 'Get cash flow entries'
      description <<~TEXT.strip
        The manually kept cash flow register behind get_amortization: the
        individual investments, subsidies, costs and revenue, as entered in the
        SOLECTRUS settings. Ask it when a single entry matters; for the
        resulting profitability ask get_amortization.

        Each entry carries `date`, `category`, `amount` and the free-text `note`
        its owner wrote. A negative `amount` is money out, a positive one money
        in. The CATEGORY, not the sign, decides how an entry counts:
          - investment base (#{CashFlow::INVESTMENT_BASE_CATEGORIES.join(', ')}):
            what has to be earned back — investment raises it, the other two
            lower it.
          - operating (#{CashFlow::OPERATING_CATEGORIES.join(', ')}): they meet
            the measured savings. manual_savings covers periods the sensors
            never saw, e.g. before SOLECTRUS was installed.
          - other: recorded, but counted nowhere in the amortization.

        `entries` is capped by `limit`; `total_count` says how many entries
        matched the filter, so a shorter list means the rest was cut off.
        `sum` and `sum_by_category` always cover ALL matching entries, not just
        the returned ones — a limited list still adds up to the totals above it.

        Money is in the system currency (see get_system_info) with 2 decimals,
        dates are ISO 8601.
      TEXT
      input_schema(
        properties: {
          from: {
            type: 'string',
            format: 'date',
            description: 'Only entries on or after this ISO 8601 date, e.g. "2024-01-01".',
          },
          to: {
            type: 'string',
            format: 'date',
            description: 'Only entries on or before this ISO 8601 date, e.g. "2024-12-31".',
          },
          categories: {
            type: 'array',
            items: {
              type: 'string',
              enum: CashFlow.categories.keys,
            },
            minItems: 1,
            description:
              'Only entries in these categories. Defaults to all of them.',
          },
          order: {
            type: 'string',
            enum: %w[desc asc],
            default: 'desc',
            description: '"desc" = newest first, "asc" = oldest first.',
          },
          limit: {
            type: 'integer',
            minimum: 1,
            maximum: 200,
            default: 50,
            description: 'Max entries returned.',
          },
        },
      )
      read_only idempotent: true

      MAX_ENTRIES = 200
      public_constant :MAX_ENTRIES

      DEFAULT_LIMIT = 50
      public_constant :DEFAULT_LIMIT

      def self.perform(from: nil, to: nil, categories: nil, order: 'desc', limit: DEFAULT_LIMIT, **)
        first_day = parse_date(from, 'from')
        last_day = parse_date(to, 'to')
        reject_inverted_range(first_day, last_day)

        selected = resolve_categories(categories)
        capped = limit.to_i.clamp(1, MAX_ENTRIES)
        scope = filtered(first_day, last_day, selected)

        payload(scope, first_day:, last_day:, selected:, order:, limit: capped)
      end

      def self.payload(scope, first_day:, last_day:, selected:, order:, limit:)
        {
          currency: Rails.configuration.x.currency,
          from: first_day&.iso8601,
          to: last_day&.iso8601,
          categories: selected,
          order: order.to_s,
          limit:,
          total_count: scope.count,
          sum: money(scope.sum(:amount)),
          sum_by_category: sum_by_category(scope),
          entries: ordered(scope, order).limit(limit).map { serialize(it) },
        }
      end
      private_class_method :payload

      def self.filtered(first_day, last_day, categories)
        scope = CashFlow.all
        scope = scope.where(date: first_day..) if first_day
        scope = scope.where(date: ..last_day) if last_day
        scope = scope.where(category: categories) if categories
        scope
      end
      private_class_method :filtered

      # Ordered by date, with created_at as the tie-breaker so entries of the
      # same day keep the order they were entered in - and a `limit` cuts the
      # list at a defined place rather than an arbitrary one.
      def self.ordered(scope, order)
        direction = order.to_s == 'asc' ? :asc : :desc
        scope.order(date: direction, created_at: direction)
      end
      private_class_method :ordered

      # Only the categories actually present, each with its signed sum. Sending
      # the empty ones too would state eight sums where the register holds
      # three, and every zero would read as "there were none of those, and we
      # checked" - which is what an absent key says more cheaply.
      def self.sum_by_category(scope)
        scope
          .group(:category)
          .sum(:amount)
          .transform_values { money(it) }
          .sort_by { |category, _sum| CashFlow.categories.keys.index(category) }
          .to_h
      end
      private_class_method :sum_by_category

      # nil (not the full list) when nothing was asked for, so the response can
      # say "all of them" by echoing null instead of enumerating the enum.
      def self.resolve_categories(categories)
        selected = Array(categories).map(&:to_s)
        selected.uniq!
        return if selected.empty?

        unknown = selected - CashFlow.categories.keys
        if unknown.any?
          raise ArgumentError,
                "Unknown cash flow #{'category'.pluralize(unknown.size)}: " \
                  "#{unknown.join(', ')}. Available: #{CashFlow.categories.keys.join(', ')}."
        end

        selected
      end
      private_class_method :resolve_categories

      # An inverted range silently matches nothing, and "no entries" is an
      # answer a client believes - so the swapped dates are named instead.
      def self.reject_inverted_range(first_day, last_day)
        return unless first_day && last_day && first_day > last_day

        raise ArgumentError,
              "Invalid range: from (#{first_day.iso8601}) is after to " \
                "(#{last_day.iso8601}). Use from=#{last_day.iso8601}, to=#{first_day.iso8601}."
      end
      private_class_method :reject_inverted_range

      def self.serialize(cash_flow)
        {
          date: cash_flow.date.iso8601,
          category: cash_flow.category,
          amount: money(cash_flow.amount),
          note: cash_flow.note,
        }
      end
      private_class_method :serialize

      def self.money(value)
        Precision.round(value, :money)
      end
      private_class_method :money
    end
  end
end
