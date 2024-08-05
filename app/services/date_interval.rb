class DateInterval
  def initialize(starts_at:, ends_at:)
    @starts_at = starts_at
    @ends_at = ends_at
  end
  attr_reader :starts_at, :ends_at

  def price_sections # rubocop:disable Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity
    return @price_sections if @price_sections

    @price_sections = []
    prices.each do |price|
      if @price_sections.empty?
        @price_sections << attributes(price)
      elsif last_section_same_start?(:electricity, price)
        last_section[:electricity] = price.value
      elsif last_section_same_start?(:feed_in, price)
        last_section[:feed_in] = price.value
      elsif price.starts_at <= starts_at
        update_section(last_section, attributes(price))
      else
        new_section = attributes(price, last_section)

        last_section[:ends_at] = price.starts_at - 1.day
        @price_sections.pop if last_section[:ends_at] < last_section[:starts_at]

        @price_sections << new_section
      end
    end

    normalized_sections(@price_sections.presence)
  end

  private

  def prices
    Price
      .where(starts_at: ..ends_at)
      .where(starts_at: ..Date.current)
      .order(:starts_at)
      .to_a
  end

  def last_section
    @price_sections.last
  end

  def last_section_same_start?(name, price)
    last_section[name].nil? && price.name == name.to_s &&
      last_section[:starts_at] == price.starts_at
  end

  def update_section(section, attributes)
    section.merge!(attributes)
  end

  def attributes(price, fallback = {})
    {
      starts_at: [price.starts_at, starts_at].max,
      ends_at:,
      electricity: price.electricity? ? price.value : fallback[:electricity],
      feed_in: price.feed_in? ? price.value : fallback[:feed_in],
    }.compact
  end

  # Ensure that there is no nil value
  def normalized_sections(sections)
    sections ||= default_sections

    sections.map do |section|
      section[:electricity] ||= 0.0
      section[:feed_in] ||= 0.0
      section
    end
  end

  def default_sections
    [{ starts_at:, ends_at: }]
  end
end
