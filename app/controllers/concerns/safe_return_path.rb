module SafeReturnPath
  extend ActiveSupport::Concern

  private

  def safe_return_path(path)
    return '/' if path.blank?

    # Only allow relative paths (no scheme, no host) starting with a single
    # forward slash. This blocks open redirects, including protocol-relative
    # URLs like "//evil.com" and backslash tricks like "/\evil.com".
    return '/' unless path.start_with?('/')
    return '/' if path.start_with?('//', '/\\')

    uri = URI.parse(path)
    return '/' if uri.scheme || uri.host

    uri.to_s
  rescue URI::InvalidURIError
    '/'
  end
end
