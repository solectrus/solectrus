class UpdateCheck::SignatureVerifier
  # Ed25519 public key for verifying update server responses.
  # The corresponding private key is held exclusively by the update server.
  PUBLIC_KEY_PEM = <<~PEM.freeze
    -----BEGIN PUBLIC KEY-----
    MCowBQYDK2VwAyEAIaLc49vPEjf5kW0iiJc+a+iM49eR3Kpfo1vawGXl8Tw=
    -----END PUBLIC KEY-----
  PEM
  private_constant :PUBLIC_KEY_PEM

  class InvalidSignatureError < StandardError; end

  def initialize(data)
    @data = data
  end

  def verify!
    signature_b64 = @data[:signature]
    raise InvalidSignatureError, 'Missing signature' if signature_b64.blank?

    signature = Base64.strict_decode64(signature_b64)
    canonical = canonical_json(@data.except(:signature, :notifications))

    unless public_key.verify(nil, signature, canonical)
      raise InvalidSignatureError, 'Invalid signature'
    end

    true
  rescue ArgumentError => e
    raise InvalidSignatureError, "Malformed signature: #{e.message}"
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

  def public_key
    @public_key ||= OpenSSL::PKey.read(PUBLIC_KEY_PEM)
  end
end
