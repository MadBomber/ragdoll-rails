# frozen_string_literal: true

Ragdoll::Rails::Engine.routes.draw do
  # Dashboard and Analytics
  get "/" => "dashboard#index", as: :root
  get "dashboard" => "dashboard#index", as: :dashboard_index
  get "analytics" => "dashboard#analytics", as: :analytics
  
  # Job Queue Dashboard
  resources :jobs, only: [:index, :show, :destroy] do
    member do
      post :retry
    end
    collection do
      get :health
      post :restart_workers
      post :bulk_delete
      post :bulk_retry
      delete :cancel_all_pending
    end
  end
  
  # Document Management
  resources :documents do
    member do
      get :preview
      post :reprocess
      get :download
    end
    collection do
      post :bulk_upload
      post :bulk_delete
      post :bulk_reprocess
      get :status
      post :upload_async
    end
  end
  
  # Search Interface
  get "search" => "search#index", as: :search_index
  post "search" => "search#search", as: :search
  
  # Configuration
  get "configuration" => "configuration#index", as: :configuration
  patch "configuration" => "configuration#update"
  
  # API endpoints for AJAX interactions
  namespace :api do
    namespace :v1 do
      resources :documents, only: [:index, :show, :create, :update, :destroy] do
        member do
          post :reprocess
        end
      end
      post "search" => "search#search"
      get "analytics" => "analytics#index"
      get "system_stats" => "system#stats"
    end
  end
end
