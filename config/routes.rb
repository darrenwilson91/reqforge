Rails.application.routes.draw do
  devise_for :users

  resources :organizations, only: [ :new, :create ]
  resources :projects do
    resources :requirements do
      member do
        patch :transition_status
      end
      collection do
        patch :reorder
        get :search
      end
    end
    resources :traceability_links, only: [ :create, :destroy ]
    resource :traceability_matrix, only: [ :show ]
    resource :traceability_graph, only: [ :show ]
    resources :reviews do
      member do
        patch :transition_status
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
