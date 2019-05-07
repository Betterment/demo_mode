DemoMode::Engine.routes.draw do
  resources :sessions, only: %i(show new create update)
end
