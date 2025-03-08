# frozen_string_literal: true

DemoMode::Engine.routes.draw do
  resources :sessions, only: %i(show new create update)
  resource :metadata, only: :create
end
