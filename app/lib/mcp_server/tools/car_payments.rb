module McpServer
  module Tools
    # The single payments of the cars (Car::Payment), where the settings list
    # them: with fuel prices for the comparison, like set_car_payment
    class CarPayments < Base
      extend PaymentList

      tool_name 'get_car_payments'
      title 'Get the payments of the cars'
      description <<~TEXT.strip
        The single payments of the electric cars, newest first, as entered in
        the settings: for example the purchase, the insurance or the GHG
        quota. get_car_costs only adds them up.

        #{PaymentList::RULES}
      TEXT
      input_schema(
        properties: {
          car: {
            type: 'integer',
            minimum: 1,
            maximum: Sensor::Cars::MAX,
            description: 'Only the payments of this car, by its number in get_system_info.',
          },
          **PaymentList::PROPERTIES,
        },
      )
      read_only idempotent: true

      def self.available? = Car.configured.any? && Car::Comparison.available?

      def self.payment_class = Car::Payment
    end
  end
end
