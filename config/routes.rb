Rails.application.routes.draw do
  get "up" => "rails/health#show", as: :rails_health_check

  resource :session, only: %i[new create destroy]
  resource :locale, only: :update
  get "bot" => "bot#show", as: :bot_info
  root "projects#index"

  resources :projects, only: %i[index show create destroy] do
    resources :domains, only: :create, shallow: true
    resources :crawls, only: %i[new create], shallow: true
  end
  resources :domains, only: :destroy do
    post :verify, on: :member
  end

  resources :crawls, only: :show do
    member do
      post :pause
      post :resume
      post :cancel
      post :audit
    end
    resources :pages, only: %i[index show], controller: "crawls/pages"
    resources :issues, only: :show, param: :check_key, controller: "crawls/issues",
      constraints: { check_key: /[a-z0-9_.]+/ }, format: false
    resources :duplicates, only: :index, controller: "crawls/duplicates"
    resources :reports, only: %i[create show], controller: "crawls/reports"
  end
end
