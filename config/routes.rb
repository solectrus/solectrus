Rails.application.routes.draw do
  # For details on the DSL available within this file, see https://guides.rubyonrails.org/routing.html

  mount Lockup::Engine, at: '/lockup' if Rails.env.production?

  resources 'cards', only: [ :index ]
  root 'home#index'
end
