# Be sure to restart your server when you modify this file.

# Define an application-wide content security policy
# For further information see the following documentation
# https://developer.mozilla.org/en-US/docs/Web/HTTP/Headers/Content-Security-Policy

Rails.application.configure do
  config.content_security_policy do |policy|
    if Rails.env.development?
      policy.script_src :self, :unsafe_eval, :unsafe_inline
      policy.connect_src :self, 'https://esbuild.solectrus.test'
    else
      policy.default_src :none
      policy.font_src :self, :data
      policy.img_src :self, :data
      policy.object_src :none
      policy.script_src :self
      policy.style_src :self, :unsafe_inline # unsafe_inline is required by Turbo's progressbar
      policy.connect_src(
        *[
          :self,
          Rails.configuration.x.plausible_url,
          (
            if Rails.configuration.x.honeybadger.api_key
              'https://api.honeybadger.io'
            end
          ),
        ].compact,
      )
      policy.manifest_src :self
      policy.frame_ancestors :none
    end
    policy.base_uri :self
    policy.form_action :self

    # Specify URI for violation reports
    # if Rails.configuration.x.honeybadger.api_key
    #   policy.report_uri(
    #     "https://api.honeybadger.io/v1/browser/csp?api_key=#{Rails.configuration.x.honeybadger.api_key}&report_only=true",
    #   )
    # end

    # Generate session nonces for permitted importmap and inline scripts
    #  config.content_security_policy_nonce_generator = ->(request) { request.session.id.to_s }
    #  config.content_security_policy_nonce_directives = %w(script-src)

    # Report CSP violations to a specified URI. See:
    # https://developer.mozilla.org/en-US/docs/Web/HTTP/Headers/Content-Security-Policy-Report-Only
    # config.content_security_policy_report_only = true
  end
end
