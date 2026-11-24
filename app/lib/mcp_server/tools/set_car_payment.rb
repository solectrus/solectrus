module McpServer
  module Tools
    # Adds or changes a payment of a car, as the admin does in the settings
    # (see Car::Payment). The number of its document finds it again (see
    # Recording). The tool deletes nothing.
    class SetCarPayment < Base
      extend Recording

      # The arguments that a call without `id` needs, because they find or add
      # the entry (see Recording#require_without_id)
      NEEDED = %i[car date category amount].freeze
      private_constant :NEEDED

      tool_name 'set_car_payment'
      title 'Add or change a payment of a car'
      description <<~TEXT.strip
        Records a payment of an electric car, for example from a bill or a
        contract: its purchase, a rate of a lease or a loan, the insurance, the
        vehicle tax, maintenance, the fees of a charging tariff, a subsidy, the
        GHG quota or its sale.

        `amount` is in the system currency (see get_system_info) and positive:
        the category says if it is an expense or an income. Only a refund of
        an expense is negative.
      TEXT
      input_schema(
        properties: {
          car: {
            type: 'integer',
            minimum: 1,
            maximum: Sensor::Cars::MAX,
            description: 'The number of the car, as get_system_info lists it.',
          },
          date: {
            type: 'string',
            format: 'date',
            description: 'ISO 8601 date of the payment, e.g. "2026-03-15".',
          },
          category: {
            type: 'string',
            enum: Car::Payment.categories.keys,
            description: "Incomes: #{Car::Payment::INCOMES.join(', ')}. The others are expenses.",
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
      def self.records = 'a payment of a car'

      # The payments of the cars have a page only with the comparison (see
      # Settings::CarPaymentsController)
      def self.available? = write_enabled? && Car::Comparison.available? && Car.configured.any?

      # The arguments and the attributes of Car::Payment they set
      ARGUMENTS = { car: :car_id, date: :date, category: :category, amount: :amount, note: :note }.freeze
      private_constant :ARGUMENTS

      def self.perform(**args)
        require_without_id(args[:id], args, NEEDED)
        car_of(args)
        attributes = attributes_from(with_date(args, :date), ARGUMENTS)

        record_payment(
          Car::Payment.all,
          reference: args[:reference].presence,
          id: args[:id],
          attributes:,
          match: attributes.slice(:car_id, :date, :category, :amount),
          arguments: ARGUMENTS,
        ) { PaymentList.serialize(it) }
      end
    end
  end
end
