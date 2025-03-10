# == Schema Information
#
# Table name: settings
#
#  id         :bigint           not null, primary key
#  value      :text
#  var        :string           not null
#  created_at :datetime         not null
#  updated_at :datetime         not null
#
# Indexes
#
#  index_settings_on_var  (var) UNIQUE
#
describe Setting do
  describe 'seed!' do
    subject(:seed!) { described_class.seed! }

    before do
      described_class.delete_all

      freeze_time
    end

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

    context 'when setup_id is zero' do
      before { described_class.setup_id = 0 }

      it 'regenerates setup_id from current time' do
        expect { seed! }.to change(described_class, :count).from(1).to(2)

        expect(described_class.setup_id).to eq(Time.current.to_i)
      end
    end

    context 'when records already exist' do
      before { described_class.seed! }

      it 'does not create further records' do
        expect { described_class.seed! }.not_to change(described_class, :count)
      end

      it 'does not change existing records' do
        expect { described_class.seed! }.not_to change(
          described_class,
          :setup_id,
        )
        expect { described_class.seed! }.not_to change(
          described_class,
          :setup_token,
        )
      end
    end
  end
end
