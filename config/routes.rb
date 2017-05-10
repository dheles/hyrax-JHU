Rails.application.routes.draw do
  mount Blacklight::Engine => '/'
  root to: "catalog#index"
  # For details on the DSL available within this file, see http://guides.rubyonrails.org/routing.html
end
