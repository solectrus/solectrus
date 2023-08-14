describe Setting do
  describe 'seed!' do
    subject(:seed!) { described_class.seed! }

    around { |example| freeze_time(&example) }

    context 'when there is no price' do
      it 'creates records' do
        expect { seed! }.to change(described_class, :count).by(2)

        expect(described_class.setup_id).to eq(Time.current.to_i)
        expect(described_class.setup_token).to be_present
      end
    end

    context 'when there is a price' do
      before do
        Price.electricity.create! value: 0.30,
                                  created_at: Time.zone.at(42),
                                  starts_at: Time.current
      end

      it 'creates records from price' do
        expect { seed! }.to change(described_class, :count).by(2)

        expect(described_class.setup_id).to eq(42)
        expect(described_class.setup_token).to be_present
      end
    end

    context 'when records already exist' do
      before { described_class.seed! }

      it 'does not create further records' do
        expect { seed! }.not_to change(described_class, :count)
      end

      it 'does not change existing reords' do
        expect { seed! }.not_to change(described_class, :setup_id)
        expect { seed! }.not_to change(described_class, :setup_token)
      end
    end
  end
end
