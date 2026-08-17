# The answer used whenever no HTTP request is made, which is every request in
# development and test. It is shaped like a real answer of the update server,
# but names only the fields a local installation needs.
module UpdateCheck::Fallback
  def fallback_data
    @fallback_data ||= {
      version: Rails.configuration.x.git.commit_version,
      registration_status: 'complete',
      # Not a real grant - the features are open because no update server was
      # asked. Naming it says so instead of claiming a sponsorship.
      premium_reason: 'development',
    }.freeze
  end
end
