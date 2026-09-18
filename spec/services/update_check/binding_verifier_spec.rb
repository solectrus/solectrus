describe UpdateCheck::BindingVerifier do
  subject(:verify!) { described_class.new(data).verify! }

  let(:data) do
    { setup_id: Setting.setup_id.to_s, expires_at: 1.hour.from_now.iso8601 }
  end

  it 'accepts an answer written for this installation' do
    expect { verify! }.not_to raise_error
  end

  # The update server sends the id as a string, this app keeps it as a number.
  context 'when the answer names the installation as a number' do
    let(:data) do
      { setup_id: Setting.setup_id, expires_at: 1.hour.from_now.iso8601 }
    end

    it 'accepts it' do
      expect { verify! }.not_to raise_error
    end
  end

  context 'when the answer was written for another installation' do
    let(:data) do
      { setup_id: 'someone-else', expires_at: 1.hour.from_now.iso8601 }
    end

    it 'refuses it' do
      expect { verify! }.to raise_error(
        described_class::InvalidBindingError,
        'Answer of another installation',
      )
    end
  end

  context 'when the answer names no installation' do
    let(:data) { { expires_at: 1.hour.from_now.iso8601 } }

    it 'refuses it' do
      expect { verify! }.to raise_error(
        described_class::InvalidBindingError,
        'Missing setup id',
      )
    end
  end

  context 'when the answer names no expiry' do
    let(:data) { { setup_id: Setting.setup_id.to_s } }

    it 'refuses it' do
      expect { verify! }.to raise_error(
        described_class::InvalidBindingError,
        'Missing expiry',
      )
    end
  end

  context 'when the expiry is not a moment' do
    let(:data) { { setup_id: Setting.setup_id.to_s, expires_at: 'whenever' } }

    it 'refuses it' do
      expect { verify! }.to raise_error(
        described_class::InvalidBindingError,
        'Missing expiry',
      )
    end
  end

  # A clock that nobody keeps drifts, and a few minutes of it say nothing
  # about an answer the update server wrote for hours.
  context 'when the clock of the installation runs a little ahead' do
    let(:data) do
      { setup_id: Setting.setup_id.to_s, expires_at: 1.minute.ago.iso8601 }
    end

    it 'accepts it' do
      expect { verify! }.not_to raise_error
    end
  end

  # An answer that just arrived gets no grace. The update server was reachable
  # then, so an expired answer is one played back.
  context 'when the answer expired' do
    let(:data) do
      { setup_id: Setting.setup_id.to_s, expires_at: 10.minutes.ago.iso8601 }
    end

    it 'refuses it' do
      expect { verify! }.to raise_error(
        described_class::InvalidBindingError,
        'Expired answer',
      )
    end

    # A cached answer is still served while the update server cannot be
    # reached. Without that window an outage of half a day would take the
    # features off every installation.
    context 'with a grace period that covers it' do
      subject(:verify!) { described_class.new(data).verify!(grace: 1.hour) }

      it 'accepts it' do
        expect { verify! }.not_to raise_error
      end
    end

    context 'with a grace period that ended too' do
      subject(:verify!) { described_class.new(data).verify!(grace: 30.seconds) }

      it 'refuses it' do
        expect { verify! }.to raise_error(
          described_class::InvalidBindingError,
          'Expired answer',
        )
      end
    end
  end
end
