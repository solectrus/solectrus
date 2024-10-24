describe 'Summaries' do
  subject(:request) { get "/summaries/#{date}" }

  let(:date) { Date.parse('2021-07-01') }

  describe 'GET /show' do
    context 'when Summary exists' do
      before { Summary.create!(date:) }

      it 'is succesful' do
        request
        expect(response).to have_http_status(:success)
      end

      it "doesn't create a new Summary" do
        expect { request }.not_to change(Summary, :count)
      end
    end

    context 'when Summary does NOT exist' do
      it 'is succesful' do
        request
        expect(response).to have_http_status(:success)
      end

      it 'creates a new Summary' do
        expect { request }.to change(Summary, :count).by(1)
        expect(Summary.last.date).to eq(date)
      end
    end
  end
end
