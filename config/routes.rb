# frozen_string_literal: true

Rails.application.routes.draw do
  # get "csv/index"
  root 'csv#index'
  # post "/", to: "csv#index"
  resources :csv, only: %i[index create] do
    collection { get :table }
  end

  resource :session, only: %i[new create destroy]
  get  '/login',  to: 'sessions#new'
  post '/login',  to: 'sessions#create'
  delete '/logout', to: 'sessions#destroy'

  resource :lunch_breaks, only: [] do
    patch :global # PATCH /lunch_breaks/global
  end

  resources :divisions, only: [:index] do
  end

  resources :users, only: [:index] do
    resources :lunch_breaks, only: %i[create update], controller: 'user_lunch_breaks'
    patch :lunch_break_default, to: 'user_lunch_breaks#default' # опционально: дефолт для пользователя
  end

  resource :worktime, only: %i[show summary export], controller: 'worktime' do # GET /worktime
    get :summary
    get :export, to: 'worktime_exports#index'
  end

  resources :users, only: [] do
    patch :update_lunch_break, on: :member # PATCH /users/:id/update_lunch_break
  end

  get 'worktime/users/:user_id/days', to: 'worktime#days', as: :worktime_user_days
  # get 'worktime/export' => 'worktime_exports#index', as: :export_worktime

  resources :import_files, only: %i[show index destroy] do
    collection do
      delete :destroy_last
    end
  end
  # root 'worktime#show'

  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  # get "up" => "rails/health#show", as: :rails_health_check

  # алиас для nginx/compose
  # get "health", to: redirect("/up")

  # Render dynamic PWA files from app/views/pwa/*
  # get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker
  # get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  get '/health', to: 'health#index'
  # Defines the root path route ("/")
  # root "posts#index"
end
