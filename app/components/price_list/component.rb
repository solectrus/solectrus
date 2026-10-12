class PriceList::Component < ViewComponent::Base
  def initialize(prices:, name:)
    super()
    @prices = prices
    @name = name
  end

  attr_reader :prices, :name

  # Only the electricity tariff can carry a base fee, so only it needs the
  # column. Price enforces the same rule.
  def base_fee_column?
    name.to_s == 'electricity'
  end

  # The per-kWh column means the opposite thing in the two tables: what a kWh
  # drawn costs, or what a kWh fed in pays. The form labels already separate
  # the two, so the header does as well. It also has to tell the reader which
  # of the two electricity columns it is.
  def amount_label
    t("activerecord.attributes.price.amounts_per_kwh.#{name}")
  end

  def list_classes
    [
      'grid grid-cols-[1fr_auto_auto] gap-x-4 select-text text-gray-800 dark:text-gray-400',
      'divide-y divide-gray-200 dark:divide-gray-700 sm:divide-y-0',
      if base_fee_column?
        'sm:grid-cols-[auto_1fr_auto_auto_auto_auto]'
      else
        'sm:grid-cols-[auto_1fr_auto_auto_auto]'
      end,
    ]
  end

  def relative_change(price, index)
    return if index == prices.length - 1

    previous_price = prices[index + 1]
    return if previous_price.amount_per_kwh.zero?

    value = ((price.amount_per_kwh / previous_price.amount_per_kwh) - 1) * 100

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
        value.positive? ? 'text-signal-negative' : 'text-signal-positive'
      when 'feed_in'
        value.positive? ? 'text-signal-positive' : 'text-signal-negative'
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
