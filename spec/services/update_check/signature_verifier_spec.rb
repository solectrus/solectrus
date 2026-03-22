describe UpdateCheck::SignatureVerifier do
  subject(:verifier) { described_class.new(payload) }

  include_context 'with signature verification'

  let(:data) { { version: 'v1.1.1', registration_status: 'complete' } }

  let(:canonical) do
    deep_sort = lambda { |obj|
      case obj
      when Hash
        obj.sort_by { |k, _| k.to_s }.to_h.transform_values { |v| deep_sort.call(v) }
      when Array
        obj.map { |v| deep_sort.call(v) }
      else
        obj
      end
    }
    JSON.generate(deep_sort.call(data))
  end

  let(:signature) do
    Base64.strict_encode64(test_private_key.sign(nil, canonical))
  end

  describe '#verify!' do
    subject(:verify) { verifier.verify! }

    let(:payload) { data.merge(signature:) }

    context 'with valid signature' do
      it { is_expected.to be true }
    end

    context 'with missing signature' do
      let(:payload) { data }

      it 'raises InvalidSignatureError' do
        expect { verify }.to raise_error(
          described_class::InvalidSignatureError,
          'Missing signature',
        )
      end
    end

    context 'with tampered data' do
      let(:payload) do
        data.merge(eligible_for_free: true, signature:)
      end

      it 'raises InvalidSignatureError' do
        expect { verify }.to raise_error(
          described_class::InvalidSignatureError,
          'Invalid signature',
        )
      end
    end

    context 'with malformed base64 signature' do
      let(:payload) { data.merge(signature: '!!!invalid!!!') }

      it 'raises InvalidSignatureError' do
        expect { verify }.to raise_error(
          described_class::InvalidSignatureError,
          /Malformed signature/,
        )
      end
    end

    context 'with wrong key' do
      let(:signature) do
        wrong_key = OpenSSL::PKey.generate_key('ED25519')
        Base64.strict_encode64(wrong_key.sign(nil, canonical))
      end

      it 'raises InvalidSignatureError' do
        expect { verify }.to raise_error(
          described_class::InvalidSignatureError,
          'Invalid signature',
        )
      end
    end

    context 'with notifications in payload' do
      let(:payload) do
        data.merge(
          notifications: [
            { id: 1, title: 'Test', body: 'Body', published_at: '2025-01-15T10:00:00Z' },
          ],
          signature:,
        )
      end

      # Notifications are excluded from canonical JSON, so signature still valid
      it { is_expected.to be true }
    end

    context 'with unsorted keys from server' do
      let(:data) do
        { version: 'v1.1.1', eligible_for_free: true, registration_status: 'complete' }
      end

      let(:canonical) do
        JSON.generate(
          eligible_for_free: true,
          registration_status: 'complete',
          version: 'v1.1.1',
        )
      end

      it { is_expected.to be true }
    end
  end
end
