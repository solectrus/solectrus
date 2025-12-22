describe SensorValue::Component, type: :component do
  around { |example| I18n.with_locale(:de) { example.run } }

  let(:timeframe) { Timeframe.day }

  def data_for(**values)
    Sensor::Data::Single.new(values, timeframe:)
  end

  describe 'rendering' do
    subject(:component) { described_class.new(data, sensor_name, **options) }

    let(:raw_data) { { inverter_power: 2500 } }
    let(:data) { data_for(**raw_data) }
    let(:sensor_name) { raw_data.keys.first }
    let(:options) { {} }

    it 'renders formatted sensor value with structure' do
      render_inline(component)

      expect(page).to have_css('span.sensor-value.sensor-inverter-power')
      expect(page).to have_css('strong.font-medium', text: '2') # 2500 / 1000 = 2.5 -> 2,5 -> integer part = '2'
      expect(page).to have_css('small', text: 'kW')
    end

    context 'with energy context' do
      let(:options) { { context: :total } }

      it 'renders kWh unit' do
        render_inline(component)

        expect(page).to have_css('small', text: 'kWh')
      end
    end

    context 'with celsius values' do
      let(:raw_data) { { case_temp: 42.7 } }

      it 'renders temperature' do
        render_inline(component)

        expect(page).to have_css('strong.font-medium', text: '42')
        expect(page).to have_css('small', text: ',7')
        expect(page).to have_css('small', text: '°C')
      end
    end

    context 'with boolean values' do
      let(:raw_data) { { wallbox_car_connected: true } }

      it 'renders boolean text without unit' do
        render_inline(component)

        expect(page).to have_css('strong.font-medium', text: 'Ja')
        expect(page).to have_no_css('small') # No unit for boolean
      end
    end

    context 'with custom CSS classes' do
      let(:options) { { class: 'text-green-600 custom-class' } }

      it 'applies custom classes' do
        render_inline(component)

        expect(page).to have_css(
          'span.sensor-value.sensor-inverter-power.text-green-600.custom-class',
        )
      end
    end

    context 'with nil values' do
      let(:raw_data) { { system_status: nil } }

      it 'handles nil values gracefully' do
        render_inline(component)

        expect(page).to have_css('span.sensor-value')
        expect(page).to have_css('strong.font-medium', text: '–')
      end

      it 'reports missing? as true' do
        expect(component.missing?).to be true
      end
    end

    context 'with sign option' do
      let(:raw_data) { { grid_costs: 45.67 } }

      context 'with sign: :negative' do
        let(:options) { { sign: :negative } }

        it 'applies red styling' do
          render_inline(component)

          expect(page).to have_css(
            'span.sensor-value.text-red-700.dark\\:text-red-400',
          )
        end
      end

      context 'with sign: :positive' do
        let(:options) { { sign: :positive } }

        it 'applies green styling' do
          render_inline(component)

          expect(page).to have_css(
            'span.sensor-value.text-green-700.dark\\:text-green-400',
          )
        end
      end

      context 'with sign: :value_based' do
        let(:options) { { sign: :value_based } }

        context 'with positive value' do
          let(:raw_data) { { grid_costs: 45.67 } }

          it 'applies green styling' do
            render_inline(component)

            expect(page).to have_css(
              'span.sensor-value.text-green-700.dark\\:text-green-400',
            )
          end
        end

        context 'with negative value' do
          let(:raw_data) { { grid_costs: -45.67 } }

          it 'applies red styling' do
            render_inline(component)

            expect(page).to have_css(
              'span.sensor-value.text-red-700.dark\\:text-red-400',
            )
          end

          it 'strips minus sign from value' do
            render_inline(component)

            # Euro values >= 10 are rounded to integer: 45.67 -> 46
            expect(page).to have_css('strong.font-medium', text: '46')
            expect(page).to have_no_text('-')
          end
        end
      end

      context 'with sign: :value_based_reverse' do
        let(:options) { { sign: :value_based_reverse } }

        context 'with positive value' do
          let(:raw_data) { { grid_costs: 45.67 } }

          it 'applies red styling (reversed)' do
            render_inline(component)

            expect(page).to have_css(
              'span.sensor-value.text-red-700.dark\\:text-red-400',
            )
          end
        end

        context 'with negative value' do
          let(:raw_data) { { grid_costs: -45.67 } }

          it 'applies green styling (reversed)' do
            render_inline(component)

            expect(page).to have_css(
              'span.sensor-value.text-green-700.dark\\:text-green-400',
            )
          end

          it 'strips minus sign from value' do
            render_inline(component)

            expect(page).to have_css('strong.font-medium', text: '46')
            expect(page).to have_no_text('-')
          end
        end
      end

      context 'with invalid sign value' do
        let(:options) { { sign: :invalid } }

        it 'raises ArgumentError' do
          expect { component }.to raise_error(
            ArgumentError,
            /Invalid sign option/,
          )
        end
      end
    end
  end

  describe 'number formatting methods' do
    subject(:component) { described_class.new(data, sensor_name) }

    let(:raw_data) { { inverter_power: 2500 } }
    let(:data) { data_for(**raw_data) }
    let(:sensor_name) { raw_data.keys.first }

    context 'with decimal values' do
      let(:raw_data) { { case_temp: 42.7 } }

      it 'returns integer part' do
        expect(component.integer_part).to eq('42')
      end

      it 'returns decimal part' do
        expect(component.decimal_part).to eq('7')
      end
    end

    context 'with integer numbers' do
      let(:raw_data) { { inverter_power: 750 } }

      it 'returns integer part' do
        expect(component.integer_part).to eq('750')
      end

      it 'returns nil decimal part' do
        expect(component.decimal_part).to be_nil
      end
    end

    context 'with scaled values' do
      let(:raw_data) { { inverter_power: 2500 } }

      it 'returns integer part' do
        expect(component.integer_part).to eq('2')
      end

      it 'returns decimal part' do
        expect(component.decimal_part).to eq('5')
      end
    end

    context 'with empty values' do
      let(:raw_data) { { system_status: nil } }

      it 'handles empty values in integer_part' do
        expect(component.integer_part).to eq('')
      end

      it 'handles empty values in decimal_part' do
        expect(component.decimal_part).to be_nil
      end
    end
  end

  describe 'value extraction' do
    let(:sensor_name) { :inverter_power }

    context 'with Data object' do
      subject(:component) { described_class.new(data, sensor_name) }

      let(:data) { data_for(inverter_power: 2500) }

      it 'extracts value from Data object' do
        expect(component.raw_value).to eq(2500)
      end
    end

    context 'with direct value' do
      subject(:component) { described_class.new(3500, sensor_name) }

      it 'uses direct value' do
        expect(component.raw_value).to eq(3500)
      end
    end
  end
end
