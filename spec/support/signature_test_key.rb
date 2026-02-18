# Shared context for tests that need real Ed25519 signature verification.
# Generates a test key pair and overrides the global stub + production key.
RSpec.shared_context 'with signature verification' do
  let(:test_private_key) { OpenSSL::PKey.generate_key('ED25519') }

  before do
    # Override global stub to test real verification
    allow_any_instance_of(UpdateCheck::SignatureVerifier) # rubocop:disable RSpec/AnyInstance
      .to receive(:verify!).and_call_original

    stub_const(
      'UpdateCheck::SignatureVerifier::PUBLIC_KEY_PEM',
      test_private_key.public_to_pem,
    )
  end
end
