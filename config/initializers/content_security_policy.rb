# Be sure to restart your server when you modify this file.

# Define an application-wide content security policy
# For further information see the following documentation
# https://developer.mozilla.org/en-US/docs/Web/HTTP/Headers/Content-Security-Policy

Rails
  .application
  .config
  .content_security_policy do |policy|
    if Rails.env.development?
      policy.script_src :self, :unsafe_eval, :unsafe_inline
      policy.connect_src :self, 'http://localhost:3035', 'ws://localhost:3035'
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
          Rails.configuration.x.plausible_url.presence,
          (
            if Rails.configuration.x.sentry_dns
              URI.parse(Rails.configuration.x.sentry_dns).host
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
    if Rails.configuration.x.sentry_csp
      policy.report_uri(Rails.configuration.x.sentry_csp)
    end
  end

# If you are using UJS then enable automatic nonce generation
# Rails.application.config.content_security_policy_nonce_generator = -> request { SecureRandom.base64(16) }

# Set the nonce only to specific directives
# Rails.application.config.content_security_policy_nonce_directives = %w(script-src)

# Report CSP violations to a specified URI
# For further information see the following documentation:
# https://developer.mozilla.org/en-US/docs/Web/HTTP/Headers/Content-Security-Policy-Report-Only
# Rails.application.config.content_security_policy_report_only = true
