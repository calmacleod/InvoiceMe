Rails.application.routes.draw do
  namespace :api do
    namespace :v1 do
      resource :google, only: %i[show destroy]
      resources :seasons, only: %i[index show create update]
      resources :contacts, only: %i[index show create update destroy]
      resources :drafts, only: %i[index show create update destroy] do
        post :preview, on: :member
      end
      resources :invoices, only: %i[index show create update destroy] do
        member do
          post :publish
          post :reopen
          post :payment
          patch :notes
          get :pdf
        end
      end
      resources :games, only: %i[index show] do
        collection do
          patch :invoicing_status
          post :import
        end
      end
    end
  end
  resource :session
  resources :contacts, except: :show
  resources :passwords, param: :token
  get "up" => "rails/health#show", as: :rails_health_check
  root "invoices#index"
  post "select_year" => "seasons#select"
  resources :seasons, only: %i[new create edit update] do
    post :select, on: :member
    get :preview, on: :member
  end
  resources :invoices do
    post :publish, on: :member
    post :reopen, on: :member
    post :payment, on: :member
    patch :notes, on: :member
  end
  resources :invoice_drafts, only: %i[index create edit update destroy] do
    post :preview, on: :member
  end
  resources :invoice_groups, only: %i[index show create update] do
    get :add_existing, on: :member
    post :attach_invoice, on: :member
  end
  resources :official_payments, only: %i[index create edit update] do
    collection do
      post :import
      get :bulk_edit
      patch :bulk_update
      post :export_sheet
    end
    member do
      get :preview
      get :pdf
      get :odt
      post :google_doc
    end
  end
  resources :games, only: %i[index new] do
    collection do
      patch :filters
      patch :invoicing_status
      post :upload
      post :preview
      get :map
      get :review
      post :commit
      get :sample
    end
  end
  resources :horizon_game_syncs, only: %i[create show destroy] do
    post :apply, on: :member
  end
  post "horizon/connect" => "horizon#connect"
  get "horizon/callback/:state" => "horizon#callback", as: :horizon_callback
  post "horizon/:id/test" => "horizon#test", as: :test_horizon
  delete "horizon/disconnect" => "horizon#disconnect"
  post "google/connect" => "google#connect"
  get "google/callback" => "google#callback"
  delete "google/disconnect" => "google#disconnect"
end
