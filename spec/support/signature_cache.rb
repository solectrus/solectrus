# Shared context for tests that need to stub HTTP responses with valid signatures.
# Generates a test key pair and provides a helper to build signed JSON bodies.
RSpec.shared_context 'with signature verification' do
  let(:test_private_key) { OpenSSL::PKey.generate_key('ED25519') }

  before do
    stub_const(
      'UpdateCheck::SignatureVerifier::PUBLIC_KEY_PEM',
      test_private_key.public_to_pem,
    )
  end

  # Build a signed JSON string suitable for stub_request body.
  def signed_json(data)
    signed = sign_data(data)
    signed.to_json
  end

  # Return a hash with signature added (for direct cache seeding).
  def sign_data(data)
    canonical = canonical_json(data.except(:signature, :notifications))
    signature = Base64.strict_encode64(test_private_key.sign(nil, canonical))
    data.merge(signature:)
  end

  private

  def canonical_json(hash)
    JSON.generate(deep_sort_keys(hash))
  end

  def deep_sort_keys(obj)
    case obj
    when Hash
      obj.sort_by { |k, _| k.to_s }
         .to_h
         .transform_values { |v| deep_sort_keys(v) }
    when Array
      obj.map { |v| deep_sort_keys(v) }
    else
      obj
    end
  end
end
