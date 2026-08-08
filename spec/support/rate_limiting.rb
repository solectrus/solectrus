# Rate limits count in a cache that lives for the whole process, so without
# this the login attempts of one example count against the next - and the suite
# locks itself out somewhere around the eleventh example that logs in.
#
# Cleared before each example rather than after, so a failure leaves the
# counter behind for inspection.
RSpec.configure do |config|
  config.before { ActionController::Base.cache_store.clear }
end
