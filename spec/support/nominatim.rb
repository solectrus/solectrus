# Place::Nominatim keeps one second between two requests of the process, so
# without this each example that asks Nominatim waits for the one before.
# The spec of the client tests the distance with a shorter one. A failure
# pauses the requests of the process, so each example starts without a pause.
RSpec.configure do |config|
  config.before do
    stub_const('Place::Nominatim::INTERVAL', 0)
    stub_const('Place::Nominatim::PAUSED_UNTIL', Concurrent::AtomicReference.new(-Float::INFINITY))
  end
end
