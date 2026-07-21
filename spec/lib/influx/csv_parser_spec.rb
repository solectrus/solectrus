describe Influx::CsvParser do
  # Real Flux output for `aggregateWindow`, including an empty bucket
  let(:body) do
    <<~CSV
      #datatype,string,long,dateTime:RFC3339,string,string,double
      #group,false,false,false,true,true,false
      #default,_result,,,,,
      ,result,table,_time,_field,_measurement,_value
      ,,0,2026-07-20T00:00:00Z,inverter_power,SENEC,1234.5
      ,,0,2026-07-20T00:05:00Z,inverter_power,SENEC,
      ,,1,2026-07-20T00:00:00Z,house_power,SENEC,678
    CSV
  end

  it 'returns one hash per row, flattened across tables' do
    rows = described_class.call(body)

    expect(rows.length).to eq(3)
    expect(rows.first).to eq(
      'result' => '_result',
      'table' => 0,
      '_time' => '2026-07-20T00:00:00Z',
      '_field' => 'inverter_power',
      '_measurement' => 'SENEC',
      '_value' => 1234.5,
    )
  end

  it 'casts by datatype' do
    rows = described_class.call(body)

    expect(rows.last['_value']).to eq(678.0)
    expect(rows.last['table']).to eq(1)
  end

  it 'maps an empty value to nil so data gaps stay visible' do
    expect(described_class.call(body)[1]['_value']).to be_nil
  end

  it 'applies the #default annotation to empty cells' do
    expect(described_class.call(body).pluck('result')).to all(eq('_result'))
  end

  it 'keeps timestamps as raw strings' do
    expect(described_class.call(body).first['_time']).to be_a(String)
  end

  context 'with several annotation blocks' do
    let(:body) do
      <<~CSV
        #datatype,string,long,double
        #group,false,false,false
        #default,_result,,
        ,result,table,_value
        ,,0,1

        #datatype,string,long,string
        #group,false,false,false
        #default,_result,,
        ,result,table,label
        ,,0,two
      CSV
    end

    it 'switches to the new schema' do
      rows = described_class.call(body)

      expect(rows).to eq(
        [
          { 'result' => '_result', 'table' => 0, '_value' => 1.0 },
          { 'result' => '_result', 'table' => 0, 'label' => 'two' },
        ],
      )
    end
  end

  context 'with quoted values' do
    let(:body) do
      <<~CSV
        #datatype,string,long,string
        #group,false,false,false
        #default,_result,,
        ,result,table,label
        ,,0,"with,comma"
      CSV
    end

    it 'falls back to a real CSV parse' do
      expect(described_class.call(body).first['label']).to eq('with,comma')
    end
  end

  context 'with boolean and infinite values' do
    let(:body) do
      <<~CSV
        #datatype,string,long,boolean,double,double
        #group,false,false,false,false,false
        #default,_result,,,,
        ,result,table,flag,high,low
        ,,0,true,+Inf,-Inf
      CSV
    end

    it 'casts them like InfluxDB2::FluxCsvParser does' do
      row = described_class.call(body).first

      expect(row['flag']).to be(true)
      expect(row['high']).to eq(Float::INFINITY)
      expect(row['low']).to eq(-Float::INFINITY)
    end
  end

  it 'returns no rows for an empty body' do
    expect(described_class.call('')).to eq([])
  end
end
