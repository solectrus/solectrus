describe ActiveSupport::Cache::RedisCacheStore, :redis do
  it 'reads back what it wrote' do
    rows = [{ time: Time.zone.parse('2026-09-25 12:00'), value: BigDecimal('1.5') }]
    Rails.cache.write('rows', rows, expires_in: 1.minute)

    expect(Rails.cache.read('rows')).to eq(rows)
  end

  it 'runs the block of fetch only on a miss' do
    calls = 0
    2.times do
      Rails.cache.fetch('answer', expires_in: 1.minute, skip_nil: true) { calls += 1 }
    end

    expect(calls).to eq(1)
  end

  it 'forgets a deleted key' do
    Rails.cache.write('key', true)
    Rails.cache.delete('key')

    expect(Rails.cache.exist?('key')).to be false
  end

  it 'forgets every key on clear' do
    Rails.cache.write('key', true)
    Rails.cache.clear

    expect(Rails.cache.exist?('key')).to be false
  end
end
