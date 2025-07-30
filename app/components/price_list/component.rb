class PriceList::Component < ViewComponent::Base
  def initialize(prices:, name:)
    super()
    @prices = prices
    @name = name
  end

  attr_reader :prices, :name

  def relative_change(price, index)
    return if index == prices.length - 1

    previous_price = prices[index + 1]
    return if previous_price.value.zero?

    value = ((price.value / previous_price.value) - 1) * 100

    ChangeComponent.new(name:, value:).call
  end

  class ChangeComponent < ViewComponent::Base
    def initialize(name:, value:)
      super()
      @name = name
      @value = value.round
    end

    attr_reader :name, :value

    def text_color
      return 'text-gray-500' if value.zero?

      case name
      when 'electricity'
        value.positive? ? 'text-red-600' : 'text-green-600'
      when 'feed_in'
        value.positive? ? 'text-green-600' : 'text-red-600'
      end
    end

    def prefix
      return if value.zero?

      (value.positive? ? '&plus;' : '&minus;').html_safe # rubocop:disable Rails/OutputSafety
    end

    def call
      tag.span class: text_color do
        safe_join([prefix, value.abs, '%'], ' ')
      end
    end
  end
end
