Rails.application.routes.draw do
  devise_for :users

  resources :organizations, only: [ :new, :create ]

  # Global search
  get "search", to: "search#index", as: :search
  get "search/autocomplete", to: "search#autocomplete", as: :search_autocomplete
  resources :projects do
    resources :requirements do
      member do
        patch :transition_status
        post :analyze_quality
        post :suggest_links
        post :analyze_impact
      end
      collection do
        patch :reorder
        get :search
        get :quick_entry
        post :quick_create
      end
    end
    resources :traceability_links, only: [ :create, :destroy ]
    resource :traceability_matrix, only: [ :show ]
    resource :traceability_graph, only: [ :show ]
    resource :compliance_dashboard, only: [ :show ]
    resource :import_export, only: [ :show ] do
      post :import_csv
      post :import_reqif
      get :export_csv
      get :export_reqif
    end
    resources :reviews do
      member do
        patch :transition_status
        post :generate_share_token
        delete :revoke_share_token
      end
      resources :review_items, only: [ :show ] do
        member do
          patch :update_status
        end
        resources :review_comments, only: [ :create ] do
          member do
            patch :resolve
            patch :unresolve
          end
        end
      end
    end
  end

  # Public shareable review links (no authentication required)
  get "reviews/:token", to: "public_reviews#show", as: :public_review
  get "reviews/:token/items/:item_id", to: "public_reviews#review_item", as: :public_review_item

  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Render dynamic PWA files from app/views/pwa/* (remember to link manifest in application.html.erb)
  # get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  # get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker

  # Defines the root path route ("/")
  root "dashboard#index"
end
