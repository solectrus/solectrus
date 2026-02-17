# Pre-populate UpdateCheck cache with sensible defaults.
# Seeds the cache directly (no HTTP) so tests work without stubs.
# Always re-seeds to prevent stale data from Spring (process preloader).
# Tests that need specific UpdateCheck behavior clear the cache themselves.
RSpec.configure do |config|
  config.before do
    UpdateCheck.instance
      .instance_variable_get(:@cache_manager)
      .set(
        UpdateCheck.instance.fallback_data,
        expires_at: 1.hour.from_now,
      )
  end
end
