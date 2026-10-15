# The change of a price against the one before, in percent. The color says
# whether the change is good: a higher electricity price is bad, a higher
# feed-in tariff is good. Nothing for the first price or after a price of zero.
class Price::List::Change::Component < ViewComponent::Base
  def initialize(price:, previous:)
    super()
    @price = price
    @previous = previous
  end

  def render?
    @previous && !@previous.amount_per_kwh.zero?
  end

  def call
    tag.span class: text_color do
      safe_join([prefix, value.abs, '%'], ' ')
    end
  end

  private

  def value
    @value ||= (((@price.amount_per_kwh / @previous.amount_per_kwh) - 1) * 100).round
  end

  def text_color
    return 'text-gray-500' if value.zero?

    case @price.name
    when 'electricity'
      value.positive? ? 'text-signal-negative' : 'text-signal-positive'
    when 'feed_in'
      value.positive? ? 'text-signal-positive' : 'text-signal-negative'
    end
  end

  def prefix
    return if value.zero?

    (value.positive? ? '&plus;' : '&minus;').html_safe # rubocop:disable Rails/OutputSafety
  end
end
