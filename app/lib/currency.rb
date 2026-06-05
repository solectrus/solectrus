# Maps an ISO-4217 currency code (configured via the CURRENCY env var) to the
# symbol shown in the UI. Codes without a common symbol fall back to the code
# itself (e.g. "CHF" stays "CHF", rendered as "CHF/kWh").
module Currency
  SYMBOLS = {
    'EUR' => '€',
    'USD' => '$',
    'GBP' => '£',
    'JPY' => '¥',
    'CNY' => '¥',
    'INR' => '₹',
  }.freeze
  private_constant :SYMBOLS

  def self.code
    Rails.configuration.x.currency
  end

  def self.symbol(currency_code = code)
    SYMBOLS.fetch(currency_code, currency_code)
  end
end
