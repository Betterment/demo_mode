Rails.application.routes.draw do
  mount DemoMode::Engine => '/ohno'

  get 'signup', as: 'foo', to: ->(_env) do
    [200, {}, ['Not a real sign up page!']]
  end

  get 'not_found_oh_no', as: 'oh_no', to: ->(_env) do
    [200, {}, ['Something should be here but is not!']]
  end

  get 'signin', as: 'bar', to: 'sessions#new'
  get 'signout', as: 'signout', to: 'sessions#destroy'

  root to: 'sessions#show'
end
