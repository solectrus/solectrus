# Pre-populate UpdateCheck cache with sensible defaults.
# Seeds the cache directly (no HTTP) so tests work without stubs.
# Re-seeds before each example, because UpdateCheck is a singleton and an
# earlier example can change or clear its cache. Tests that need specific
# UpdateCheck behavior clear the cache themselves.
RSpec.configure do |config|
  config.before do
    UpdateCheck.instance.cache_manager.set(
      UpdateCheck.instance.fallback_data,
      fresh_until: 1.hour.from_now,
      usable_until: 25.hours.from_now,
    )
  end
end
