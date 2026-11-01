# The first locale of an Accept-Language header that the app offers, by the
# quality values of the header. A region falls back to its language, so
# "de-AT" picks :de.
module AcceptLanguage
  def self.locale_from(header, available_locales)
    preferred_tags(header).each do |tag|
      match = available_locales.find { |locale| matches?(locale.to_s, tag) }
      return match if match
    end

    nil
  end

  def self.matches?(locale, tag)
    locale.casecmp?(tag) ||
      locale.split('-', 2).first.casecmp?(tag.split('-', 2).first)
  end

  # The language tags by descending quality, in the order of the header for an
  # equal quality
  def self.preferred_tags(header)
    entries =
      header.to_s.delete(' ').split(',').each_with_index.filter_map do |entry, index|
        tag, quality = parse(entry)
        [tag, quality, index] if tag
      end

    entries.sort_by { |_tag, quality, index| [-quality, index] }.map(&:first)
  end

  # "de-AT;q=0.8" gives ["de-AT", 0.8]. A wildcard names no language, and
  # "q=0" rejects one, so both give nil.
  def self.parse(entry)
    tag, *params = entry.split(';')
    quality = params.find { it.start_with?('q=') }&.delete_prefix('q=')&.to_f || 1.0
    return if tag.blank? || tag == '*' || quality <= 0

    [tag, quality]
  end

  private_class_method :matches?, :preferred_tags, :parse
end
