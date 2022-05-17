# Be sure to restart your server when you modify this file.

# Define an application-wide content security policy.
# See the Securing Rails Applications Guide for more information:
# https://guides.rubyonrails.org/security.html#content-security-policy-header

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
      policy.script_src :self,
                        '\'sha256-W49+qLXTvblxo3uhW+zCJ7W79iSK1/XLC2fBoPuDgHM=\'' # Lockup
      policy.style_src :self, :unsafe_inline
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

    # Report violations without enforcing the policy.
    # config.content_security_policy_report_only = true
  end
end
