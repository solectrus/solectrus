class Sensor::Units::Boolean < Sensor::Units::Base
  # The words of a boolean value, for a source that sends text, for example
  # MQTT. The case does not matter.
  TRUE_WORDS = %w[true on yes].freeze
  private_constant :TRUE_WORDS

  FALSE_WORDS = %w[false off no].freeze
  private_constant :FALSE_WORDS

  # true or false, or nil for a value that is no boolean. A number is true
  # when it is positive, so an error code like -1 is false.
  def self.parse(raw_value)
    case raw_value
    when true, false then raw_value
    when Numeric then raw_value.positive?
    when String
      word = raw_value.strip.downcase
      if TRUE_WORDS.include?(word) then true
      elsif FALSE_WORDS.include?(word) then false
      else Float(word, exception: false)&.positive?
      end
    end
  end

  delegate :parse, to: :class

  def format(printed_value, **)
    I18n.t(printed_value ? 'general.yes' : 'general.no')
  end
end
