module McpServer
  module Tools
    # Adds or changes a cash flow of the PV system, which the amortization
    # counts, as the admin does in the settings (see CashFlow). The number of
    # its document finds it again (see Recording). The tool deletes nothing.
    class SetCashFlow < Base
      extend Recording

      # The arguments that a call without `id` needs, because they find or add
      # the entry (see Recording#require_without_id)
      NEEDED = %i[date category amount note].freeze
      private_constant :NEEDED

      tool_name 'set_cash_flow'
      title 'Add or change a cash flow of the PV system'
      description <<~TEXT.strip
        Records an investment, a cost or a revenue of the PV system, which
        get_amortization counts, for example from a bill. get_cash_flows lists
        the existing entries. Not for the payments of a car or of the heat
        pump, and not for the electricity bought or fed in: that comes from the
        measurements and the prices.

        `amount` is in the system currency (see get_system_info) and carries a
        sign: negative for money paid (investment, operating_cost, repair),
        positive for money received (subsidy, refund, compensation,
        manual_savings). other takes either sign.
      TEXT
      input_schema(
        properties: {
          date: {
            type: 'string',
            format: 'date',
            description: 'ISO 8601 date of the payment, e.g. "2026-03-15".',
          },
          category: {
            type: 'string',
            enum: CashFlow.categories.keys,
          },
          amount: {
            type: 'number',
            description: 'The amount with its sign, e.g. -1200 for a repair.',
          },
          note: {
            type: 'string',
            minLength: 1,
            description: 'What was paid, e.g. "Replacement of the inverter".',
          },
          reference: Recording::REFERENCE_PROPERTY,
          id: Recording.id_property(*NEEDED),
        },
      )
      writes idempotent: true, destructive: true

      # What the tool records, for the instructions of the server
      def self.records = 'an investment, a cost or a revenue of the PV system'

      def self.available? = write_enabled?

      # The arguments and the attributes of CashFlow they set
      ARGUMENTS = { date: :date, category: :category, amount: :amount, note: :note }.freeze
      private_constant :ARGUMENTS

      def self.perform(**args)
        require_without_id(args[:id], args, NEEDED)
        attributes = attributes_from(with_date(args, :date), ARGUMENTS)

        record_payment(
          CashFlow.all,
          reference: args[:reference].presence,
          id: args[:id],
          attributes:,
          match: attributes.slice(:date, :category, :amount),
          arguments: ARGUMENTS,
        ) { CashFlows.serialize(it) }
      end
    end
  end
end
