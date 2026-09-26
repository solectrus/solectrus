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
        independent of `limit`, which caps only the returned lists so an
        unbounded one is never dumped unless asked for, and null where the
        history begins after `date`.

        `history` covers the changes UP TO `date`, so the entry `effective` was
        read from is always in it — the newest one under the default
        order="desc". A change that only takes effect AFTER `date` is not
        history yet and is listed separately under `upcoming`, oldest first;
        the field is absent when nothing is pending. Never quote an `upcoming`
        value as the current price.

        Every rate is per kWh in the system currency (see get_system_info).

        An electricity tariff can also carry a monthly base fee for the grid
        connection: `base_fee_per_month` in the history, and
        `effective_base_fee_per_month` beside `effective`. Both are absent
        where the tariff has none. The fee is part of the grid costs and is
        prorated by day, so a get_totals figure already contains it.
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
        on = parse_date(date) || Date.current
        currency = Rails.configuration.x.currency
        capped = limit.to_i.clamp(1, 100)

        prices =
          Price.names.keys.map do |name|
            # The changes in effect up to `on`, capped by `limit`.
            #
            # Bounded by `on` rather than by the newest entry, because the two
            # disagree the moment a price change is scheduled ahead or a past
            # date is asked about: date=2023-06-15 with limit=2 used to answer
            # effective 0.4451 next to a history of 2026 and 2025, in which that
            # value did not appear at all. Capping at `on` is what makes the list
            # explain the number above it.
            #
            # The cap applies from the `on` end regardless of `order`, so the
            # entry `effective` came from survives even a limit of 1: `order`
            # decides how the kept entries are presented, not which ones are
            # kept.
            records = Price.where(name:).in_force_on(on).limit(capped).to_a

            # Newest first, so the first record is the tariff in force on `date`
            # - one query answers the history and the effective values alike. It
            # carries both halves of the tariff, the rate per kWh and the base
            # fee.
            effective = records.first

            {
              name:,
              # Named for the value it describes, not for the object it sits
              # in: `effective` is a rate per kWh, while the base fee beside it
              # is an amount per month. A bare `unit` here claimed to cover
              # both.
              unit_per_kwh: "#{currency}/kWh",
              # Named for what it is - the price valid on `date` - rather than
              # "current", which claimed today's tariff even when `date` asked
              # about 2023.
              effective:
                Precision.round(effective&.amount_per_kwh, :money_per_kwh),
              **base_fee_of(effective, key: :effective_base_fee_per_month),
              history: sort_history(records.map { serialize(it) }, sort:, order:),
              **upcoming_for(name, on:, limit: capped),
            }
          end

        { date: on.iso8601, currency:, sort:, order:, limit: capped, prices: }
      end

      # Changes that only take effect after `on`. Their own field rather than a
      # flag inside the history: a scheduled tariff sitting in a list called
      # "history" reads as the current one, and a client quoting it is wrong by
      # however long it is until it starts.
      def self.upcoming_for(name, on:, limit:)
        entries =
          Price
            .where(name:)
            .where(starts_at: (on + 1)..)
            .order(starts_at: :asc)
            .limit(limit)
            .map { serialize(it) }

        entries.any? ? { upcoming: entries } : {}
      end
      private_class_method :upcoming_for

      def self.sort_history(entries, sort:, order:)
        ascending = order.to_s == 'asc'
        # Sort by value with the date as a stable tie-breaker; otherwise by date.
        sorted =
          if sort.to_s == 'value'
            entries.sort_by { |entry| [entry[:value], entry[:starts_at]] }
          else
            entries.sort_by { |entry| entry[:starts_at] }
          end

        ascending ? sorted : sorted.reverse
      end
      private_class_method :sort_history

      def self.serialize(price)
        {
          starts_at: price.starts_at.iso8601,
          value: Precision.round(price.amount_per_kwh, :money_per_kwh),
          **base_fee_of(price),
          note: price.note,
        }
      end
      private_class_method :serialize

      # The fee is left out where a tariff has none, and it only ever appears
      # on electricity: the fee buys the grid connection, so the feed-in tariff
      # cannot carry one. Price enforces that rule, so the tool only omits an
      # absent value.
      def self.base_fee_of(price, key: :base_fee_per_month)
        amount = price&.amount_per_month
        return {} unless amount

        { key => Precision.round(amount, :money) }
      end
      private_class_method :base_fee_of
    end
  end
end
