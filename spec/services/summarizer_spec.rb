describe Summarizer do
  describe '.perform!' do
    context 'when from is before to' do
      subject { described_class.perform!(from:, to:) }

      let(:from) { Date.current - 1.day }
      let(:to) { from + 1.day }

      it { is_expected.to be_truthy }
    end

    context 'when from is after to' do
      subject(:perform) { described_class.perform!(from:, to:) }

      let(:from) { Date.current }
      let(:to) { from - 1.day }

      it { expect { perform }.to raise_error(ArgumentError) }
    end

    context 'when block is given' do
      let(:from) { 20.days.ago.to_date }
      let(:to) { from + 2.days }

      it do
        callbacks = []
        described_class.perform!(from:, to:) do |index, count|
          callbacks.push([index, count])
        end

        # 3 days, 33% each
        expect(callbacks).to eq([[1, 3], [2, 3], [3, 3]])
      end
    end
  end

  describe '#initialize' do
    subject { described_class.new(date) }

    let(:date) { Date.current }

    it { is_expected.to have_attributes(date:) }
  end

  describe '#perform' do
    subject(:perform) { summarizer.perform! }

    let(:summarizer) { described_class.new(date) }
    let(:date) { Date.current }

    context 'when summary does not exist' do
      it { expect { perform }.to change(Summary, :count).by(1) }
    end

    context 'when summary exists' do
      before { Summary.create!(date:) }

      it { expect { perform }.not_to change(Summary, :count) }
    end
  end
end
