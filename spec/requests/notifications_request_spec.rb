describe 'Notifications' do
  let!(:notification) do
    Notification.create!(
      title: 'Test Notification',
      body: '<p>Test body</p>',
      published_at: 1.day.ago,
    )
  end

  describe 'GET /notifications' do
    context 'when not logged in' do
      it 'returns http success' do
        get '/notifications'
        expect(response).to have_http_status(:success)
      end

      it 'explains that reading needs the login' do
        get '/notifications'
        expect(response.body).to include(
          'Only the administrator of this instance can read them',
        )
      end

      it 'offers a link to the login' do
        get '/notifications'
        expect(response.body).to include(
          CGI.escapeHTML(new_session_path(return_to: notifications_path)),
        )
      end

      it 'does not disclose the notification' do
        get '/notifications'
        expect(response.body).not_to include('Test Notification')
      end

      it 'shows the number of unread messages on the icon' do
        get '/notifications'
        expect(response.body).to include('notification-unread-count')
      end

      it 'says that the red mark stays' do
        get '/notifications'
        expect(response.body).to include(
          'The red mark stays until someone logs in',
        )
      end

      context 'when everything is read' do
        before { notification.mark_as_read! }

        it 'shows no count' do
          get '/notifications'
          expect(response.body).not_to include('notification-unread-count')
        end

        it 'still explains the page' do
          get '/notifications'
          expect(response.body).to include('News about SOLECTRUS appears here')
        end

        # No mark stands on the screen now, so naming one would send the guest
        # looking for something that is not there.
        it 'does not mention a red mark' do
          get '/notifications'
          expect(response.body).not_to include('The red mark stays')
        end
      end

      context 'when no notifications exist' do
        before { Notification.delete_all }

        it 'redirects to root' do
          get '/notifications'
          expect(response).to redirect_to(root_path)
        end
      end
    end

    context 'when logged in as admin' do
      before { login_as_admin }

      it 'returns http success' do
        get '/notifications'
        expect(response).to have_http_status(:success)
      end

      it 'displays the notification' do
        get '/notifications'
        expect(response.body).to include('Test Notification')
      end

      # The list page is public, so a logout here must stay here. It is the one
      # page a fresh guest should see, and bouncing to the homepage would hide
      # the explanation the red mark points at.
      it 'lets a logout return to this page' do
        get '/notifications'
        expect(response.body).to include(
          CGI.escapeHTML(session_path(return_to: notifications_path)),
        )
      end

      context 'when no notifications exist' do
        before { Notification.delete_all }

        it 'redirects to root' do
          get '/notifications'
          expect(response).to redirect_to(root_path)
        end
      end
    end
  end

  describe 'GET /notifications/:id' do
    context 'when not logged in' do
      it 'returns http forbidden' do
        get "/notifications/#{notification.id}"
        expect(response).to have_http_status(:forbidden)
      end
    end

    context 'when logged in as admin' do
      before { login_as_admin }

      it 'returns http success' do
        get "/notifications/#{notification.id}"
        expect(response).to have_http_status(:success)
      end

      it 'displays the notification content' do
        get "/notifications/#{notification.id}"
        expect(response.body).to include('Test body')
      end

      it 'leaves the notification unread' do
        expect do
          get "/notifications/#{notification.id}"
        end.not_to change { notification.reload.read? }.from(false)
      end

      context 'when notification does not exist' do
        it 'redirects to index' do
          get '/notifications/999999'
          expect(response).to redirect_to(notifications_path)
        end
      end
    end
  end

  describe 'GET /notifications/latest' do
    context 'when not logged in' do
      it 'returns http forbidden' do
        get '/notifications/latest'
        expect(response).to have_http_status(:forbidden)
      end
    end

    context 'when logged in as admin' do
      before { login_as_admin }

      it 'returns http success' do
        get '/notifications/latest'
        expect(response).to have_http_status(:success)
      end

      it 'leaves the notification unread' do
        expect do
          get '/notifications/latest'
        end.not_to change { notification.reload.read? }.from(false)
      end

      context 'when nothing is unread' do
        before { notification.mark_as_read! }

        it 'redirects to index' do
          get '/notifications/latest'
          expect(response).to redirect_to(notifications_path)
        end
      end
    end
  end

  describe 'PATCH /notifications/:id/mark_as_read' do
    context 'when not logged in' do
      it 'returns http forbidden' do
        patch "/notifications/#{notification.id}/mark_as_read"
        expect(response).to have_http_status(:forbidden)
      end
    end

    context 'when logged in as admin' do
      before { login_as_admin }

      it 'redirects back' do
        patch "/notifications/#{notification.id}/mark_as_read"
        expect(response).to have_http_status(:redirect)
      end

      it 'marks the notification as read' do
        expect do
          patch "/notifications/#{notification.id}/mark_as_read"
        end.to change { notification.reload.read? }.from(false).to(true)
      end

      context 'when notification does not exist' do
        it 'redirects to index' do
          patch '/notifications/999999/mark_as_read'
          expect(response).to redirect_to(notifications_path)
        end
      end
    end
  end
end
