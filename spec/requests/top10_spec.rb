describe 'Top 10' do
  describe 'GET /top10' do
    it_behaves_like 'localized request', '/top10/day/inverter_power'
  end
end
