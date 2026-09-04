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

  # Typography of the notification body. The line width comes from the narrow
  # modal panel, so the prose itself must not limit it again.
  BODY_CLASS = [
    'prose prose-sm sm:prose-base max-w-none',
    'text-gray-700 dark:text-gray-300',
    'prose-headings:text-inherit prose-headings:text-base prose-headings:font-semibold prose-headings:mt-6 prose-headings:mb-2',
    'prose-p:my-4 prose-p:leading-relaxed',
    'prose-ul:my-4 prose-ol:my-4 prose-li:my-1.5 marker:text-indigo-400 dark:marker:text-indigo-500',
    'prose-a:text-indigo-600 dark:prose-a:text-indigo-400 prose-a:font-medium prose-a:break-words prose-a:underline-offset-2 prose-a:decoration-indigo-300 dark:prose-a:decoration-indigo-700 hover:prose-a:text-indigo-500',
    'prose-strong:text-inherit prose-em:text-inherit prose-code:text-inherit',
  ].join(' ').freeze
  private_constant :BODY_CLASS

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
