# == Schema Information
#
# Table name: settings
#
#  id         :bigint           not null, primary key
#  value      :text
#  var        :string           not null
#  created_at :datetime         not null
#  updated_at :datetime         not null
#
# Indexes
#
#  index_settings_on_var  (var) UNIQUE
#
class Setting < RailsSettings::Base
  cache_prefix { 'v2' }

  field :setup_id, type: :integer
  field :setup_token, type: :string

  field :plant_name, type: :string
  field :operator_name, type: :string

  field :summary_config, type: :json, default: {}
  field :sensor_names, type: :hash, default: {}
  field :inverter_as_total, type: :boolean, default: true

  # Whether the amortization calculation is visible to non-admin visitors.
  # Admins always see it; this opt-in exposes it to everyone else.
  field :amortization_public, type: :boolean, default: false

  field :enable_multi_inverter, type: :boolean, default: true
  field :enable_custom_consumer, type: :boolean, default: true
  field :enable_heatpump, type: :boolean, default: true
  field :enable_forecast, type: :boolean, default: true

  # Read-only data access via Model Context Protocol (/mcp). Disabled by
  # default; admins opt in via the general settings. When enabled, access is
  # protected by stateless OAuth (auth code + PKCE), authenticated with the
  # existing admin password - no token is stored. See McpOauth.
  field :mcp_enabled, type: :boolean, default: false

  # Rotatable salt mixed into the OAuth signing key. Rotating it invalidates
  # every issued token at once (used to drop all clients when MCP is disabled).
  # Blank until first rotated. See McpOauth.signing_key.
  field :mcp_oauth_secret, type: :string

  def self.seed!
    current_id = Setting.setup_id
    if current_id.nil? || current_id.zero?
      Setting.setup_id = (Price.first&.created_at || Time.current).to_i
    end
    Setting.setup_token ||= SecureRandom.alphanumeric(16)
  end
end
