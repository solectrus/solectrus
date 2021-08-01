class PagesController < ApplicationController
  def show
    raise ActionController::RoutingError, 'Not found' unless valid_page?

    render template: "pages/#{params[:page]}"
  end

  private

  def valid_page?
    File.exist? Rails.root.join(
                  'app',
                  'views',
                  'pages',
                  "#{params[:page]}.html.slim",
                )
  end
end
