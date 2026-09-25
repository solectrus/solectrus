# Production caches in Redis, the test environment in a null store. An example
# tagged :redis runs against a real Redis instead, so a broken update of the
# redis gem fails a spec and not the first installation that runs it.
#
# CI starts Redis, so there every example tagged :redis runs, and a missing
# server fails it. A local run without Redis leaves them out.
module RedisHelper
  URL = 'redis://localhost:6379/15'.freeze

  # Each spec process keeps its keys under a namespace of its own, and
  # Rails.cache.clear deletes only those.
  STORE =
    ActiveSupport::Cache.lookup_store(
      :redis_cache_store,
      url: URL,
      namespace: "solectrus-test#{ENV.fetch('TEST_ENV_NUMBER', nil)}",
    )

  public_constant :URL, :STORE

  def self.available?
    STORE.redis.with(&:ping) == 'PONG'
  rescue Redis::BaseConnectionError
    false
  end
end

RSpec.configure do |config|
  config.filter_run_excluding(:redis) unless ENV['CI'] || RedisHelper.available?

  config.before(:each, :redis) do
    allow(Rails).to receive(:cache).and_return(RedisHelper::STORE)
    Rails.cache.clear
  end
end
