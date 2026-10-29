Rails.application.routes.draw do
  get "up" => "rails/health#show", as: :rails_health_check
  get "login" => "sessions#new"
  post "login" => "sessions#create"
  delete "logout" => "sessions#destroy"
  root "invoices#index"
  post "select_year" => "seasons#select"
  resources :seasons, only: %i[new create edit update] do
    post :select, on: :member
    get :preview, on: :member
  end
  resources :invoices do
    post :publish, on: :member
    post :payment, on: :member
    patch :notes, on: :member
  end
  resources :games, only: %i[index new] do
    collection do
      post :upload
      post :preview
      post :commit
      get :sample
    end
  end
  post "google/connect" => "google#connect"
  get "google/callback" => "google#callback"
  delete "google/disconnect" => "google#disconnect"
end
