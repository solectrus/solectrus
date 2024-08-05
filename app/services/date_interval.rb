class DateInterval
  def initialize(starts_at:, ends_at:)
    @starts_at = starts_at
    @ends_at = ends_at
  end
  attr_reader :starts_at, :ends_at

  def price_sections
    @price_sections ||= build_price_sections
  end

  private

  def build_price_sections
    sections = []
    prices.each do |price|
      last_section = sections.last

      if sections.empty?
        sections << attributes(price)
      elsif same_start?(last_section, :electricity, price)
        last_section[:electricity] = price.value
      elsif same_start?(last_section, :feed_in, price)
        last_section[:feed_in] = price.value
      elsif price.starts_at <= starts_at
        update_section(last_section, attributes(price))
      else
        new_section = attributes(price, last_section)

        last_section[:ends_at] = price.starts_at - 1.day
        sections.pop if last_section[:ends_at] < last_section[:starts_at]

        sections << new_section
      end
    end

    normalized_sections(sections.presence)
  end

  def prices
    Price
      .where(starts_at: ..ends_at)
      .where(starts_at: ..Date.current)
      .order(:starts_at)
      .to_a
  end

  def same_start?(section, name, price)
    section[name].nil? && price.name == name.to_s &&
      section[:starts_at] == price.starts_at
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
