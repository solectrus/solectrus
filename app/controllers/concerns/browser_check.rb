# Enforce modern browser requirements for Tailwind CSS 4 compatibility.
#
# Tailwind CSS 4 requires modern CSS features (@property, color-mix, OKLCH)
# that are only available in recent browser versions.
# See: https://tailwindcss.com/docs/compatibility
#
# The browser check can be bypassed in two ways:
# 1. Per-user: Visit /skip_browser_check to set a permanent cookie
# 2. Instance-wide: Set environment variable SKIP_BROWSER_CHECK=true
#
module BrowserCheck
  extend ActiveSupport::Concern

  included do
    allow_browser versions: {
                    chrome: 111,
                    safari: 16.4,
                    firefox: 128,
                    ie: false,
                  },
                  unless: -> { browser_check_disabled? },
                  except: %i[skip_browser_check]
  end

  # Public action accessible via route to skip browser check for current user
  def skip_browser_check
    cookies.permanent[:skip_browser_check] = 'true'
    redirect_to balance_home_path
  end

  private

  # Check if browser check is disabled for this request
  def browser_check_disabled?
    # Cookie-based skip (per user)
    cookies[:skip_browser_check] == 'true' ||
      # Environment-based skip (entire instance, useful for demo/testing)
      ENV['SKIP_BROWSER_CHECK'] == 'true'
  end
end

# Log blocked browsers to help identify issues with website checkers/bots
ActiveSupport::Notifications.subscribe(
  'browser_block.action_controller',
) do |_name, _started, _finished, _unique_id, payload|
  request = payload[:request]
  Rails.logger.warn(
    "Browser blocked (unsupported version): User-Agent='#{request.user_agent}' IP=#{request.remote_ip}",
  )
end
