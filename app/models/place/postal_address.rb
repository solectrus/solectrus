# An address in the form of a charging point: "DE-12345 Town, Main Street 15".
# Each part can be missing.
#
# An address of the user and the answer of Nominatim complete each other
# (see #completed_by). Nominatim knows the country, the postcode and the
# spelling of the street. It does not know each house number, and its town
# can be a part of the town or a group of towns, so the user wins there.
Place::PostalAddress = Data.define(:country_code, :postcode, :town, :street, :house_number)

# The methods and the constants sit in a class body, like ChargingSession::Sums
class Place::PostalAddress
  # The country code in front: "DE-", or "de-" as the user typed it. A
  # mixed case is a word: "St-Martin".
  COUNTRY_CODE = /\A([A-Z]{2}|[a-z]{2})-/
  private_constant :COUNTRY_CODE

  # A postcode with its town: "12345 Town", or "1234 AB Town" in the
  # Netherlands. A street can stand before it: "Main Street 15 12345 Town".
  LOCALITY = /\A(?:(?<street>.+?)\s+)?(?<postcode>\d{4,5}(?:\s?[A-Z]{2}\b)?)\s+(?<town>\D.*)\z/
  private_constant :LOCALITY

  # A house number after a street: "15", "3 a", "0A" or "34 - 35"
  HOUSE_NUMBER = %r{\A(?<street>.*?\S)\s+(?<number>\d+(?:\s?[a-z])?(?:\s?[-/]\s?\d+(?:\s?[a-z])?)?)\z}i
  private_constant :HOUSE_NUMBER

  # The country code in front of an address and the rest of it: "DE-12345
  # Town" gives ["DE", "12345 Town"], an address without a code [nil, text]
  def self.split_country(text)
    match = COUNTRY_CODE.match(text)
    match ? [match[1].upcase, match.post_match] : [nil, text]
  end

  # The parts of an address that a user wrote, as far as they are clear. The
  # first part without a postcode is the street.
  def self.parse(text)
    code, rest = split_country(text)
    parts = { country_code: code }
    rest.split(',').map(&:squish).each do |part|
      if (match = LOCALITY.match(part))
        parts[:postcode] = match[:postcode]
        parts.merge!(town_parts(match[:town]))
        part = match[:street]
      end
      parts.merge!(street_parts(part)) if part.present? && !parts.key?(:street)
    end
    new(**members.index_with(nil), **parts)
  end

  # The town after a postcode. A town that ends with a house number holds
  # the street too: "12345 Town Main Street 15". Where the town ends is not
  # clear, so the town and the street of Nominatim win (see #completed_by).
  def self.town_parts(text)
    HOUSE_NUMBER.match?(text) ? street_parts(text).merge(town: nil) : { town: text }
  end
  private_class_method :town_parts

  def self.street_parts(part)
    match = HOUSE_NUMBER.match(part)
    match ? { street: match[:street], house_number: match[:number] } : { street: part }
  end
  private_class_method :street_parts

  # This address of the user, completed by the address that Nominatim found
  # (see the class)
  def completed_by(found)
    self.class.new(
      country_code: found.country_code || country_code,
      postcode: found.postcode || postcode,
      town: town || found.town,
      street: found.street || street,
      house_number: house_number || found.house_number,
    )
  end

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
