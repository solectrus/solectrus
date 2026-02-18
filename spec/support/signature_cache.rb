# Skip Ed25519 signature verification in all tests by default.
# The test suite seeds the UpdateCheck cache directly (no HTTP),
# so cached data has no signature.
# Only SignatureVerifier specs test real verification.
RSpec.configure do |config|
  # rubocop:disable RSpec/AnyInstance
  config.before do
    allow_any_instance_of(UpdateCheck::SignatureVerifier)
      .to receive(:verify!).and_return(true)
  end
  # rubocop:enable RSpec/AnyInstance
end
