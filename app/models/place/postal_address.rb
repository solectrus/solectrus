# An address in the form of a charging point: "DE-12345 Town, Main Street 15",
# built from the answer of Nominatim (see Place#postal_address). Each part can
# be missing.
Place::PostalAddress = Data.define(:country_code, :postcode, :town, :street, :house_number)

# The methods sit in a class body, like ChargingSession::Sums
class Place::PostalAddress
  def to_s
    code = [country_code, postcode].compact.join('-').presence
    locality = [code, town].compact.join(' ').presence

    [locality, street_line].compact.join(', ')
  end

  # The street first and without the country, as within the country: "Main
  # Street 15, 12345 Town"
  def domestic
    locality = [postcode, town].compact.join(' ').presence

    [street_line, locality].compact.join(', ')
  end

  private

  def street_line = [street, house_number].compact.join(' ').presence
end
