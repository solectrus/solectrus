module McpServer
  module Tools
    # The single payments of the heat pump (Heatpump::Payment), where the
    # settings list them, like set_heatpump_payment
    class HeatpumpPayments < Base
      extend PaymentList

      tool_name 'get_heatpump_payments'
      title 'Get the payments of the heat pump'
      description <<~TEXT.strip
        The single payments of the heat pump, newest first, as entered in the
        settings: for example the purchase, the maintenance or a subsidy.

        #{PaymentList::RULES}
      TEXT
      input_schema(properties: PaymentList::PROPERTIES)
      read_only idempotent: true

      def self.available? = Heatpump::Comparison.settings?

      def self.payment_class = Heatpump::Payment
    end
  end
end
