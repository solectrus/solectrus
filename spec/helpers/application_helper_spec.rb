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

    it { is_expected.to eq '<span>1</span><span class="text-base">,2</span><span>&nbsp;kWh</span>' }
  end

  describe 'number_to_kw' do
    subject { number_to_kw(value) }

    let(:value) { 1234 }

    it { is_expected.to eq '<span>1</span><span class="text-base">,234</span><span>&nbsp;kW</span>' }
  end
end
