Rails.application.routes.draw do
  get "up" => "rails/health#show", as: :rails_health_check
  get "status" => "status#show", as: :status

  root "home#show"
  resource :session, only: %i[new create destroy]
  resource :registration, only: %i[new create], path: "sign_up", path_names: { new: "" }
  resource :locale, only: :update
  get "bot" => "bot#show", as: :bot_info

  resources :projects, only: %i[index show create update destroy] do
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

  namespace :settings do
    resources :api_tokens, only: %i[index create destroy]
  end

  namespace :admin do
    resources :users, only: %i[index destroy]
  end

  # JSON API (docs/api/openapi.yaml, rendered at /api/docs).
  get "api/docs" => "api_docs#show", as: :api_docs
  get "api/docs/openapi.yaml" => "api_docs#spec", as: :api_spec
  namespace :api, defaults: { format: :json } do
    namespace :v1 do
      get "me" => "me#show"
      resources :projects, only: %i[index show create update destroy] do
        resources :domains, only: %i[index create], shallow: true
        resources :crawls, only: %i[index create], shallow: true
      end
      resources :domains, only: %i[show destroy] do
        post :verify, on: :member
      end
      resources :crawls, only: :show do
        member do
          post :pause
          post :resume
          post :cancel
        end
        resources :pages, only: :index, controller: "crawl_pages"
        resources :issues, only: :index, controller: "crawl_issues"
      end
    end
  end
end
