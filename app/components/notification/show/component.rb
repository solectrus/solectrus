class Notification::Show::Component < ViewComponent::Base
  SOLECTRUS_DOMAIN = 'solectrus.de'.freeze
  private_constant :SOLECTRUS_DOMAIN

  UTM_PARAMS = {
    'utm_source' => 'solectrus-app',
    'utm_medium' => 'notification',
  }.freeze
  private_constant :UTM_PARAMS

  def initialize(notification:)
    super()
    @notification = notification
  end

  attr_reader :notification

  delegate :title, :body, :formatted_published_at, to: :notification

  # Sanitize the body and force every link to open in a new browser tab.
  # Without this, links inside the notification modal would replace the
  # current Turbo Frame instead of opening externally.
  # Links pointing to solectrus.de get UTM parameters appended for tracking.
  def safe_body
    fragment = Nokogiri::HTML5.fragment(body)
    fragment.css('a').each do |link|
      link['target'] = '_blank'
      link['rel'] = 'noopener'
      link['href'] = decorate_href(link['href']) if link['href']
    end
    helpers.sanitize(
      fragment.to_html,
      attributes:
        Rails::HTML5::SafeListSanitizer.allowed_attributes + %w[target rel],
    )
  end

  private

  def decorate_href(href)
    uri = URI.parse(href)
    return href unless solectrus_host?(uri.host)

    params = URI.decode_www_form(uri.query.to_s).to_h
    UTM_PARAMS.each { |key, value| params[key] ||= value }
    uri.query = URI.encode_www_form(params)
    uri.to_s
  rescue URI::InvalidURIError
    href
  end

  def solectrus_host?(host)
    return false if host.blank?

    host = host.downcase
    host == SOLECTRUS_DOMAIN || host.end_with?(".#{SOLECTRUS_DOMAIN}")
  end
end
