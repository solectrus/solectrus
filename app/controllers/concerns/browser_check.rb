module BrowserCheck
  extend ActiveSupport::Concern

  included do
    # Tailwind CSS 4 requires modern browser versions
    # https://tailwindcss.com/docs/compatibility
    allow_browser versions: {
                    chrome: 111,
                    safari: 16.4,
                    firefox: 128,
                    ie: false,
                  },
                  unless: -> { cookies[:skip_browser_check] == 'true' },
                  except: %i[skip_browser_check]

    # We allow the browser check to be skipped via special route
    def skip_browser_check
      cookies.permanent[:skip_browser_check] = 'true'
      redirect_to root_path
    end
  end
end
