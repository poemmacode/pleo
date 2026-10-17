Rails.application.routes.draw do
  get "up" => "rails/health#show", as: :rails_health_check

  namespace :api do
    namespace :v1 do
      resource :csrf_token, only: :show
      resource :session, only: %i[show create destroy]

      resources :projects, only: %i[index show create update destroy] do
        resources :domains, only: %i[index create], shallow: true
        resources :crawls, only: %i[index create], shallow: true
      end
      resources :crawls, only: :show do
        member do
          post :pause
          post :resume
          post :cancel
        end
        resources :pages, only: %i[index show], controller: "crawl_pages"
        get :urls, to: "crawl_pages#urls"
        get :duplicates, to: "crawl_pages#duplicates"
        get :issues, to: "crawl_issues#index"
        get "issues/:check_key", to: "crawl_issues#show", constraints: { check_key: /[a-z0-9_.]+/ }, format: false
        post :audit, to: "crawl_issues#rerun"
      end
      resources :domains, only: %i[show destroy] do
        post :verify, on: :member
      end
    end
  end
end
