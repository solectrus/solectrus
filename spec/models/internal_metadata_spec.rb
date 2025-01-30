describe InternalMetadata do
  describe '.created_at' do
    it 'returns the created_at timestamp of the first record' do
      expect(described_class.created_at).to be_a(Time)
    end
  end
end
