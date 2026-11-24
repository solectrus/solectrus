module McpServer
  module Tools
    # What get_car_payments and get_heatpump_payments share: the payments of
    # one class (see Payment), which get_car_costs only ever returns added up
    # by category. A question about one of them, or a check before an entry,
    # needs the payments themselves. Each tool names the class with
    # `payment_class` and shows only where the settings have its list, like
    # its tool that writes.
    module PaymentList
      # How a list answers, for the description of each tool
      RULES = <<~TEXT.strip.freeze
        `amount` is positive: the category says if it is an expense or an
        income, and only a refund of an expense is negative. `sum` and
        `sum_by_category` cover ALL matching payments, an income positive.
        `origin` says who wrote it last: `user` (the admin) or `mcp` (an AI
        agent). `total_count` says how many matched, also beyond `limit`.
      TEXT
      public_constant :RULES

      # The input-schema properties that both tools take
      PROPERTIES = {
        category: {
          type: 'string',
          description: 'Only the payments of this category, e.g. "maintenance".',
        },
        from: {
          type: 'string',
          format: 'date',
          description: 'Only payments on or after this ISO 8601 date.',
        },
        to: {
          type: 'string',
          format: 'date',
          description: 'Only payments on or before this ISO 8601 date.',
        },
        limit: {
          type: 'integer',
          minimum: 1,
          maximum: CashFlows::MAX_ENTRIES,
          default: CashFlows::DEFAULT_LIMIT,
          description: 'Max payments returned.',
        },
      }.freeze
      public_constant :PROPERTIES

      # A payment as the two tools list it, which set_car_payment and
      # set_heatpump_payment answer with as well
      def self.serialize(payment)
        {
          id: payment.id,
          **({ car: payment.car_id } if payment.car_id),
          date: payment.date&.iso8601,
          category: payment.category,
          amount: money(payment.amount),
          note: payment.note,
          reference: payment.reference,
          origin: payment.origin,
        }
      end

      def self.money(value) = Precision.round(value, :money)

      def perform(from: nil, to: nil, limit: CashFlows::DEFAULT_LIMIT, **filters)
        first_day = parse_date(from, 'from')
        last_day = parse_date(to, 'to')
        reject_inverted_range(first_day, last_day)

        scope = filtered(first_day, last_day, **filters.slice(:car, :category))
        capped = limit.to_i.clamp(1, CashFlows::MAX_ENTRIES)

        {
          currency: Rails.configuration.x.currency,
          total_count: scope.count,
          sum: PaymentList.money(scope.signed_sum),
          sum_by_category: scope.group(:category).signed_sum.transform_values { PaymentList.money(it) },
          payments: scope.ordered.limit(capped).map { PaymentList.serialize(it) },
        }
      end

      private

      def filtered(first_day, last_day, car: nil, category: nil)
        scope = payment_class.all
        scope = scope.where(date: first_day..) if first_day
        scope = scope.where(date: ..last_day) if last_day
        scope = scope.where(car_id: car) if car
        scope = scope.where(category: known_category(category)) if category
        scope
      end

      # A category of another kind silently matches nothing, and "no payments"
      # is an answer a client believes - so it names the categories instead
      def known_category(category)
        categories = payment_class.categories.keys
        return category if category.in?(categories)

        raise ArgumentError, "Unknown category #{category.inspect}. Available: #{categories.join(', ')}."
      end
    end
  end
end
