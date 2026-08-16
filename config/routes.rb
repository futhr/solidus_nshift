# frozen_string_literal: true

SolidusNshift::Engine.routes.draw do
  resources :rate_selections, only: :update

  namespace :admin do
    resources :connections
    resources :fulfillments, only: %i[index show] do
      member do
        post :book
        post :reconcile
        post :sync_tracking
        post :cancel
        post :refresh_documents
      end
    end
    resources :documents, only: :show
  end
end
