module McpServer
  module Tools
    # Adds or changes a payment of the heat pump, as the admin does in the
    # settings (see Heatpump::Payment). The number of its document finds it
    # again (see Recording). The tool deletes nothing.
    class SetHeatpumpPayment < Base
      extend Recording

      # The arguments that a call without `id` needs, because they find or add
      # the entry (see Recording#require_without_id)
      NEEDED = %i[date category amount].freeze
      private_constant :NEEDED

      tool_name 'set_heatpump_payment'
      title 'Add or change a payment of the heat pump'
      description <<~TEXT.strip
        Records a payment of the heat pump, for example from a bill or a
        contract: its purchase with the installation, maintenance, operating
        costs or a subsidy. Not for the electricity it uses: that comes from
        the measurements and the prices.

        `amount` is in the system currency (see get_system_info) and positive:
        the category says if it is an expense or an income. Only a refund of
        an expense is negative.
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
            enum: Heatpump::Payment.categories.keys,
            # The hints of the form (settings.heatpump_payments.category_hint)
            description:
              'Expenses: purchase (the device, its installation and accessories like a meter, also the ' \
              'rates of a loan for them), maintenance (repairs too), operating_costs (for example a ' \
              'meter of its own or the standing charge of a heat pump tariff), other_expense. ' \
              'Incomes: subsidy.',
          },
          amount: {
            type: 'number',
            description: 'The amount, positive. Negative only for a refund of an expense.',
          },
          note: Recording::NOTE_PROPERTY,
          reference: Recording::REFERENCE_PROPERTY,
          id: Recording.id_property(*NEEDED),
        },
      )
      writes idempotent: true, destructive: true

      # What the tool records, for the instructions of the server
      def self.records = 'a payment of the heat pump'

      # The payments of the heat pump have a page only with its settings
      def self.available? = write_enabled? && Heatpump::Comparison.settings?

      # The arguments and the attributes of Heatpump::Payment they set
      ARGUMENTS = { date: :date, category: :category, amount: :amount, note: :note }.freeze
      private_constant :ARGUMENTS

      def self.perform(**args)
        require_without_id(args[:id], args, NEEDED)
        attributes = attributes_from(with_date(args, :date), ARGUMENTS)

        record_payment(
          Heatpump::Payment.all,
          reference: args[:reference].presence,
          id: args[:id],
          attributes:,
          match: attributes.slice(:date, :category, :amount),
          arguments: ARGUMENTS,
        ) { PaymentList.serialize(it) }
      end
    end
  end
end
