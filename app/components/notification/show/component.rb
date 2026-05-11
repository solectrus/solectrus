class Notification::Show::Component < ViewComponent::Base
  def initialize(notification:)
    super()
    @notification = notification
  end

  attr_reader :notification

  delegate :title, :body, :formatted_published_at, to: :notification

  # Sanitize the body and force every link to open in a new browser tab.
  # Without this, links inside the notification modal would replace the
  # current Turbo Frame instead of opening externally.
  def safe_body
    fragment = Nokogiri::HTML5.fragment(body)
    fragment.css('a').each do |link|
      link['target'] = '_blank'
      link['rel'] = 'noopener'
    end
    helpers.sanitize(
      fragment.to_html,
      attributes:
        Rails::HTML5::SafeListSanitizer.allowed_attributes + %w[target rel],
    )
  end
end
