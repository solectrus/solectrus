describe Sensor::Definitions::Colors do
  subject(:colors) { described_class.new(meta_data) }

  let(:meta_data) { {} }

  describe '#color' do
    context 'with static colors' do
      it 'stores background and text classes' do
        colors.color(background: 'bg-blue-500', text: 'text-white')

        expect(meta_data[:color_background]).to eq('bg-blue-500')
        expect(meta_data[:color_text]).to eq('text-white')
      end

      it 'stores optional border class' do
        colors.color(background: 'bg-blue-500', text: 'text-white', border: 'border-blue-500')

        expect(meta_data[:color_border]).to eq('border-blue-500')
      end

      it 'raises when bg or text are not strings' do
        expect { colors.color(background: :blue, text: 'text-white') }
          .to raise_error(ArgumentError, /background and text as strings/)
      end
    end

    context 'with gradient colors' do
      let(:gradient) do
        colors.gradient(
          from: -10,
          to: 40,
          start: 'bg-cold',
          stop: 'bg-hot',
        )
      end

      it 'stores color scale and fallback classes' do
        colors.color(background: gradient, text: 'text-white')

        expect(meta_data[:color_background_scale]).to eq([[-10.0, 'bg-cold'], [40.0, 'bg-hot']])
        expect(meta_data[:color_background]).to eq('bg-hot')
        expect(meta_data[:color_text]).to eq('text-white')
      end

      it 'allows optional border class' do
        colors.color(background: gradient, text: 'text-white', border: 'border-white')

        expect(meta_data[:color_border]).to eq('border-white')
      end

      it 'raises when text is not a string' do
        expect { colors.color(background: gradient, text: :white) }
          .to raise_error(ArgumentError, /text as a string/)
      end
    end

    context 'with dynamic block' do
      it 'stores the color block' do
        colors.color { |value| { background: value } }

        expect(meta_data[:color_dynamic]).to be_a(Proc)
      end

      it 'rejects extra options' do
        expect { colors.color(background: 'bg-blue-500') { |_| {} } }
          .to raise_error(ArgumentError, /does not accept other options/)
      end
    end
  end

  describe '#gradient' do
    it 'returns a typed gradient hash' do
      gradient = colors.gradient(from: 0, to: 100, start: 'bg-low', stop: 'bg-high')

      expect(gradient).to eq(
        type: :gradient,
        from: 0,
        to: 100,
        start: 'bg-low',
        stop: 'bg-high',
      )
    end
  end
end
