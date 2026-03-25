# For details on the DSL available within this file, see http://guides.rubyonrails.org/routing.html
Rails.application.routes.draw do
  draw :jumpstart

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", :as => :rails_health_check

  # Render dynamic PWA files from app/views/pwa/* (remember to link manifest in application.html.erb)
  # get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  # get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker

  authenticated :user do
    root to: "hke/welcome#index", as: :user_root
  end

  # Public marketing homepage
  root to: "hke/welcome#index"

  # Short link redirect (public)
  get "/me/:code", to: "hke/short_links#redirect", as: :short_link

  # Contact self-service portal (public, token-based)
  scope "/portal/:portal_token", as: :portal do
    get "/", to: "hke/portal/dashboard#show", as: :dashboard
    get "/profile", to: "hke/portal/profile#show", as: :profile
    get "/profile/edit", to: "hke/portal/profile#edit", as: :edit_profile
    patch "/profile", to: "hke/portal/profile#update"
    get "/preferences", to: "hke/portal/preferences#show", as: :preferences
    patch "/preferences", to: "hke/portal/preferences#update"
    patch "/preferences/relation/:relation_id", to: "hke/portal/preferences#update_relation_preference", as: :relation_preference
    get "/venues", to: "hke/portal/venues#index", as: :venues
    post "/venues/:venue_id/request", to: "hke/portal/venues#request_venue", as: :venue_request
    get  "/deceased/:id",      to: "hke/portal/deceased#show",    as: :deceased
    get  "/deceased/:id/edit", to: "hke/portal/deceased#edit",    as: :edit_deceased
    patch "/deceased/:id",     to: "hke/portal/deceased#update",   as: :update_deceased
    delete "/deceased/:id",    to: "hke/portal/deceased#destroy",  as: :destroy_deceased
  end

  # HKE routes (inlined from engine)
  namespace :hke, path: "/hke" do
    # System Admin Routes
    namespace :admin do
      resources :communities do
        resources :users, controller: "community_users"
      end
      post :switch_to_community, to: "dashboard#switch_to_community"
      root to: "dashboard#show"
    end

    # Community Admin Routes
    resource :system_preferences, only: [:show, :edit, :update, :destroy] do
      patch :impact_preview, on: :collection
    end

    resource :community_preferences, only: [:show, :edit, :update, :destroy] do
      patch :impact_preview, on: :collection
    end

    resources :logs, only: [:index] do
      collection do
        delete :destroy_all
      end
    end
    resources :cemeteries
    resources :communities, only: [:show, :edit, :update]

    resources :future_messages do
      member do
        post :blast
        post :toggle_approval
        get  :preview
      end
      collection do
        get :approve
        post :bulk_approve
        post :approve_all
        post :disapprove_all
      end
    end

    resources :csv_imports, only: [:new, :create, :show, :index, :destroy] do
      collection do
        delete :destroy_all
      end
    end

    resources :message_management, only: [:index, :show]
    resources :landing_pages do
      collection do
        get :sms_preview
        get :send_test_email
      end
    end

    resources :contact_people do
      collection do
        post :import_csv
      end
    end

    resources :deceased_people do
      collection do
        post :import_csv
      end
    end

    resources :users, except: [:show] do
      collection do
        get :profile, action: :edit
        patch :profile, action: :update
      end
    end

    namespace :api, defaults: {format: :json} do
      namespace :v1 do
        post "twilio/sms/status", to: "twilio_callback#sms_status"
        post "sendgrid/events",  to: "sendgrid_callback#events"
        resource :system, only: [:show, :edit, :update, :create]
        resources :cemeteries
        resources :communities
        resources :future_messages do
          member do
            post :blast
          end
        end
        resources :deceased_people
        resources :contact_people
        resources :relations
        resources :csv_imports, only: [:index, :show, :create, :update]
        resources :csv_import_logs, only: [:create]
      end
    end

    root to: "dashboard#show"
  end
end
