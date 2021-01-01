describe ApplicationHelper do
  describe 'number_to_eur' do
    subject { number_to_eur(value) }

    context 'when positive' do
      let(:value) { 1.234 }

      it { is_expected.to eq '<span class="text-green-500">1,23 €</span>' }
    end

    context 'when negative' do
      let(:value) { -1.234 }

      it { is_expected.to eq '<span class="text-red-500">-1,23 €</span>' }
    end
  end

  describe 'number_to_kwh' do
    subject { number_to_kwh(value) }

    let(:value) { 1234 }

    it { is_expected.to eq '1,234 kWh' }
  end
end
